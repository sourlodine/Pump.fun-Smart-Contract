// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/INonfungiblePositionManager.sol';
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "./libraries/Constants.sol";
import {CallbackLib} from "./libraries/CallbackLib.sol";

import {BancorBondingCurve} from "./BancorBondingCurve.sol";
import {Token} from "./Token.sol";

contract TokenFactory is ReentrancyGuard, Ownable {
    enum TokenState {
        NOT_CREATED,
        FUNDING,
        TRADING
    }

    uint256 public constant MAX_SUPPLY = 10 ** 9 * 1 ether; // 1 Billion
    uint256 public constant INITIAL_SUPPLY = (MAX_SUPPLY * 1) / 5;
    uint256 public constant FUNDING_SUPPLY = (MAX_SUPPLY * 4) / 5;
    uint256 public constant FUNDING_GOAL = 20 ether;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint24 public constant UNISWAP_FEE = 10000;
    uint256 internal constant FULL_RANGE_LIQUIDITY_AMOUNT_WETH = 0.1 ether;
    uint256 internal constant FULL_RANGE_LIQUIDITY_AMOUNT_TOKEN = 1e6;
    

    mapping(address => TokenState) public tokens;

    mapping(uint256 => address[]) public tokensByCompetitionId;

    mapping(address => uint256) public competitionIds;
    uint256 public currentCompetitionId = 0;

    address public immutable tokenImplementation;
    address internal immutable WETH;
    address public uniswapV3Factory;
    BancorBondingCurve public bondingCurve;
    uint256 public feePercent; // bp
    uint256 public fee;

    mapping(uint256 => address) public winners;
    mapping(uint256 => mapping(address => uint256)) public collateralById;

    // Events
    event TokenCreated(
        address indexed token,
        string name,
        string symbol,
        string uri,
        address creator,
        uint256 competitionId,
        uint256 timestamp
    );

    event TokenLiqudityAdded(address indexed token, uint256 timestamp);

    event TokenBuy(
        address indexed token,
        uint256 amount0In,
        uint256 amount0Out,
        uint256 fee,
        uint256 timestamp
    );

    event TokenSell(
        address indexed token,
        uint256 amount0In,
        uint256 amount0Out,
        uint256 fee,
        uint256 timestamp
    );

    event SetWinner(
        address indexed winner, 
        uint256 competitionId,
        uint256 timestamp
    );

    event BurnTokenAndMintWinner(
        address indexed sender,
        address indexed token,
        address indexed winnerToken,
        uint256 burnedAmount,
        uint256 receivedETH,
        uint256 mintedAmount,
        uint256 timestamp
    );

    constructor(
        address _tokenImplementation,
        address _uniswapV3Factory,
        address _bondingCurve,
        address _weth,
        uint256 _feePercent
    ) Ownable(msg.sender) {
        tokenImplementation = _tokenImplementation;
        uniswapV3Factory = _uniswapV3Factory;
        bondingCurve = BancorBondingCurve(_bondingCurve);
        feePercent = _feePercent;
        WETH = _weth;
    }

    modifier inCompetition(address tokenAddress) {
        require(
            competitionIds[tokenAddress] == currentCompetitionId,
            "The competition for this token has already ended"
        );
        _;
    }

    // Admin functions

    function startNewCompetition() external onlyOwner {
        currentCompetitionId = currentCompetitionId + 1;
    }

    function setBondingCurve(address _bondingCurve) external onlyOwner {
        bondingCurve = BancorBondingCurve(_bondingCurve);
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        feePercent = _feePercent;
    }

    function claimFee() external onlyOwner {
        (bool success, ) = msg.sender.call{value: fee}(new bytes(0));
        require(success, "ETH send failed");
        fee = 0;
    }

    // Token functions

    function createToken(
        string memory name,
        string memory symbol,
        string memory uri
    ) external returns (address) {
        address tokenAddress = Clones.clone(tokenImplementation);
        Token token = Token(tokenAddress);
        token.initialize(name, symbol, uri, address(this));
        tokens[tokenAddress] = TokenState.FUNDING;

        tokensByCompetitionId[currentCompetitionId].push(tokenAddress);

        competitionIds[tokenAddress] = currentCompetitionId;

        emit TokenCreated(
            tokenAddress,
            name,
            symbol,
            uri,
            msg.sender,
            currentCompetitionId,
            block.timestamp
        );

        return tokenAddress;
    }

    function buy(address tokenAddress) external payable nonReentrant inCompetition(tokenAddress) {
        _buy(tokenAddress, msg.sender, msg.value);
    }

    function _buy(
        address tokenAddress,
        address receiver,
        uint256 valueToBuy
    ) internal returns (uint256) {
        require(tokens[tokenAddress] == TokenState.FUNDING, "Token not found");
        require(valueToBuy > 0, "ETH not enough");
        // calculate fee
        uint256 valueToReturn;
        uint256 _competitionId = competitionIds[tokenAddress];
        uint256 tokenCollateral = collateralById[_competitionId][tokenAddress];

        uint256 remainingEthNeeded = FUNDING_GOAL - tokenCollateral;
        uint256 contributionWithoutFee = (valueToBuy * FEE_DENOMINATOR) /
            (FEE_DENOMINATOR + feePercent);
        if (contributionWithoutFee > remainingEthNeeded) {
            contributionWithoutFee = remainingEthNeeded;
        }
        uint256 _fee = calculateFee(contributionWithoutFee, feePercent);
        uint256 totalCharged = contributionWithoutFee + _fee;
        valueToReturn = valueToBuy > totalCharged
            ? valueToBuy - totalCharged
            : 0;
        fee += _fee;
        Token token = Token(tokenAddress);
        uint256 amount = bondingCurve.computeMintingAmountFromPrice(
            collateralById[_competitionId][tokenAddress],
            token.totalSupply(),
            contributionWithoutFee
        );
        uint256 availableSupply = FUNDING_SUPPLY - token.totalSupply();
        require(amount <= availableSupply, "Token supply not enough");
        tokenCollateral += contributionWithoutFee;
        token.mint(receiver, amount);

        collateralById[_competitionId][tokenAddress] = tokenCollateral;

        // TODO - return left not working for burnTokenAndMintWinner case
        // return left
        // if (valueToReturn > 0) {
        //     (bool success, ) = receiver.call{value: amount - valueToBuy}(
        //         new bytes(0)
        //     );
        //     require(success, "ETH send failed");
        // }

        emit TokenBuy(tokenAddress, valueToBuy, amount, fee, block.timestamp);

        return (amount);
    }

    function sell(address tokenAddress, uint256 amount) external nonReentrant inCompetition(tokenAddress) {
        _sell(tokenAddress, amount, msg.sender, msg.sender);
    }

    function _sell(
        address tokenAddress,
        uint256 amount,
        address from,
        address to
    ) internal returns (uint256) {
        require(
            tokens[tokenAddress] == TokenState.FUNDING,
            "Token is not funding"
        );
        require(amount > 0, "Amount should be greater than zero");
        
        Token token = Token(tokenAddress);
        uint256 _competitionId = competitionIds[tokenAddress];

        uint256 receivedETH = bondingCurve.computeRefundForBurning(
            collateralById[_competitionId][tokenAddress],
            token.totalSupply(),
            amount
        );
        // calculate fee
        uint256 _fee = calculateFee(receivedETH, feePercent);
        receivedETH -= _fee;
        fee += _fee;
        token.burn(from, amount);
        collateralById[_competitionId][tokenAddress] -= receivedETH;
        // send ether
        //slither-disable-next-line arbitrary-send-eth

        if (to != address(this)) {
            (bool success, ) = to.call{value: receivedETH}(new bytes(0));
            require(success, "ETH send failed");
        }

        emit TokenSell(tokenAddress, amount, receivedETH, fee, block.timestamp);

        return receivedETH;
    }

    // Internal functions

    function createLiquilityPool(
        address tokenAddress
    ) internal returns (address) {
        IUniswapV3Factory factory = IUniswapV3Factory(uniswapV3Factory);

        address pool = factory.createPool(tokenAddress, WETH, UNISWAP_FEE);

        return pool;
    }

    function addLiquidity(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 ethAmount
    ) internal returns (uint256 amount0, uint256 amount1) {
        Token token = Token(tokenAddress);
        IUniswapV3Factory factory = IUniswapV3Factory(uniswapV3Factory);
        address poolAddress = factory.getPool(tokenAddress, WETH, UNISWAP_FEE);
        
        token.approve(poolAddress, tokenAmount);

        return _mintFullRange(
            IUniswapV3Pool(poolAddress),
            tokenAddress,
            WETH,
            uint128(tokenAmount),
            UNISWAP_FEE,
            1
        );
    }

    function burnLiquidityToken(address pair, uint256 liquidity) internal {
        SafeERC20.safeTransfer(IERC20(pair), address(0), liquidity);
    }

    function calculateFee(
        uint256 _amount,
        uint256 _feePercent
    ) internal pure returns (uint256) {
        return (_amount * _feePercent) / FEE_DENOMINATOR;
    }

    function getWinnerByCompetitionId(uint256 competitionId) public view returns (address) {
        uint256 maxCollateral = 0;
        address winnerAddress;

        for (uint256 i = 0; i < tokensByCompetitionId[competitionId].length; i++) {
            address tokenAddress = tokensByCompetitionId[competitionId][i];
            uint256 _collateral = collateralById[competitionId][tokenAddress];

            if (_collateral > maxCollateral) {
                maxCollateral = _collateral;
                winnerAddress = tokenAddress;
            }
        }

        return winnerAddress;
    }

    function setWinnerByCompetitionId(uint256 competitionId) external {
        require(competitionId != currentCompetitionId, 'The competition is still active');

        address winnerAddress = getWinnerByCompetitionId(competitionId);

        if(winners[competitionId] != winnerAddress) {
            winners[competitionId] = winnerAddress;
            emit SetWinner(winnerAddress, competitionId, block.timestamp);
        }
    }

    function burnTokenAndMintWinner(
        address tokenAddress
    ) external nonReentrant {
        uint256 _competitionId = competitionIds[tokenAddress];
        
        require(_competitionId != currentCompetitionId, 'The competition is still active');

        address winnerToken = getWinnerByCompetitionId(_competitionId);

        // require(winnerToken != tokenAddress, "token address is the winner");

        Token token = Token(tokenAddress);

        if(winnerToken == tokenAddress) {
            createLiquilityPool(tokenAddress);

            uint256 ethAmount = collateralById[_competitionId][tokenAddress];

            token.mint(address(this), INITIAL_SUPPLY);
            addLiquidity(tokenAddress, INITIAL_SUPPLY, ethAmount);
        } else {
            uint256 burnedAmount = token.balanceOf(msg.sender);

            uint256 receivedETH = _sell(
                tokenAddress,
                burnedAmount,
                msg.sender,
                address(this)
            );

            uint256 mintedAmount = _buy(winnerToken, msg.sender, receivedETH);

            emit BurnTokenAndMintWinner(
                msg.sender,
                tokenAddress,
                winnerToken,
                burnedAmount,
                receivedETH,
                mintedAmount,
                block.timestamp
            );
        }
    }

    /// @notice Seeds Uniswap V3 pool with a full-tick-range liquidity deployment using funds from caller.
    /// @param v3Pool The address of the Uniswap V3 pool to deploy liquidity in.
    /// @param token0 The address of the first token in the Uniswap V3 pool.
    /// @param token1 The address of the second token in the Uniswap V3 pool.
    /// @param fee The fee level of the of the underlying Uniswap v3 pool, denominated in hundredths of bips
    /// @param tickSpacing The tick spacing of the underlying Uniswap v3 pool
    /// @return the amount of token0 deployed at full range
    /// @return the amount of token1 deployed at full range
    function _mintFullRange(
        IUniswapV3Pool v3Pool,
        address token0,
        address token1,
        uint128 amount,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (uint256, uint256) {
        // get current tick
        (uint160 currentSqrtPriceX96, , , , , , ) = v3Pool.slot0();

        // build callback data
        bytes memory mintdata = abi.encode(
            CallbackLib.CallbackData({ // compute by reading values from univ3pool every time
                    poolFeatures: CallbackLib.PoolFeatures({
                        token0: token0,
                        token1: token1,
                        fee: fee
                    }),
                    payer: _msgSender()
                })
        );

        // For full range: L = Δx * sqrt(P) = Δy / sqrt(P)
        // We start with fixed delta amounts and apply this equation to calculate the liquidity
        // uint128 fullRangeLiquidity;
        // unchecked {
        //     // Since we know one of the tokens is WETH, we simply add 0.1 ETH + worth in tokens
        //     if (token0 == WETH) {
        //         fullRangeLiquidity = uint128(
        //             (FULL_RANGE_LIQUIDITY_AMOUNT_WETH * currentSqrtPriceX96) / Constants.FP96
        //         );
        //     } else if (token1 == WETH) {
        //         fullRangeLiquidity = uint128(
        //             (FULL_RANGE_LIQUIDITY_AMOUNT_WETH * Constants.FP96) / currentSqrtPriceX96
        //         );
        //     } else {
        //         // Find the resulting liquidity for providing 1e6 of both tokens
        //         uint128 liquidity0 = uint128(
        //             (FULL_RANGE_LIQUIDITY_AMOUNT_TOKEN * currentSqrtPriceX96) / Constants.FP96
        //         );
        //         uint128 liquidity1 = uint128(
        //             (FULL_RANGE_LIQUIDITY_AMOUNT_TOKEN * Constants.FP96) / currentSqrtPriceX96
        //         );

        //         // Pick the greater of the liquidities - i.e the more "expensive" option
        //         // This ensures that the liquidity added is sufficiently large
        //         fullRangeLiquidity = liquidity0 > liquidity1 ? liquidity0 : liquidity1;
        //     }
        // }

        /// mint the required amount in the Uniswap pool
        /// this triggers the uniswap mint callback function
        return
            IUniswapV3Pool(v3Pool).mint(
                address(this),
                (Constants.MIN_V3POOL_TICK / tickSpacing) * tickSpacing,
                (Constants.MAX_V3POOL_TICK / tickSpacing) * tickSpacing,
                amount,
                mintdata
            );
    }
}
