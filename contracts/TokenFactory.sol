// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {BondingCurve} from "./BondingCurve.sol";
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

    mapping(address => TokenState) public tokens;
    mapping(uint => address) private tokensAddresses;
    uint totalTokensAddresses;

    mapping(address => uint256) public collateral;
    address public immutable tokenImplementation;
    address public uniswapV2Router;
    address public uniswapV2Factory;
    BondingCurve public bondingCurve;
    uint256 public feePercent; // bp
    uint256 public fee;

    // Events
    event TokenCreated(
        address indexed token,
        string name,
        string symbol,
        string uri,
        address creator,
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

    constructor(
        address _tokenImplementation,
        address _uniswapV2Router,
        address _uniswapV2Factory,
        address _bondingCurve,
        uint256 _feePercent
    ) Ownable(msg.sender) {
        tokenImplementation = _tokenImplementation;
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Factory = _uniswapV2Factory;
        bondingCurve = BondingCurve(_bondingCurve);
        feePercent = _feePercent;
    }

    // Admin functions

    function setBondingCurve(address _bondingCurve) external onlyOwner {
        bondingCurve = BondingCurve(_bondingCurve);
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

        tokensAddresses[totalTokensAddresses] = tokenAddress;
        totalTokensAddresses++;

        emit TokenCreated(
            tokenAddress,
            name,
            symbol,
            uri,
            msg.sender,
            block.timestamp
        );

        return tokenAddress;
    }

    function buy(address tokenAddress) external payable nonReentrant {
        require(tokens[tokenAddress] == TokenState.FUNDING, "Token not found");
        require(msg.value > 0, "ETH not enough");
        // calculate fee
        uint256 valueToBuy = msg.value;
        uint256 valueToReturn;
        uint256 tokenCollateral = collateral[tokenAddress];

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
        uint256 amount = bondingCurve.getAmountOut(
            token.totalSupply(),
            contributionWithoutFee
        );
        uint256 availableSupply = FUNDING_SUPPLY - token.totalSupply();
        require(amount <= availableSupply, "Token supply not enough");
        tokenCollateral += contributionWithoutFee;
        token.mint(msg.sender, amount);
        // when reached FUNDING_GOAL
        // if (tokenCollateral >= FUNDING_GOAL) {
        //     token.mint(address(this), INITIAL_SUPPLY);
        //     address pair = createLiquilityPool(tokenAddress);
        //     uint256 liquidity = addLiquidity(
        //         tokenAddress,
        //         INITIAL_SUPPLY,
        //         tokenCollateral
        //     );
        //     burnLiquidityToken(pair, liquidity);
        //     tokenCollateral = 0;
        //     tokens[tokenAddress] = TokenState.TRADING;
        //     emit TokenLiqudityAdded(tokenAddress, block.timestamp);
        // }
        collateral[tokenAddress] = tokenCollateral;
        // return left
        if (valueToReturn > 0) {
            (bool success, ) = msg.sender.call{value: msg.value - valueToBuy}(
                new bytes(0)
            );
            require(success, "ETH send failed");
        }

        emit TokenBuy(tokenAddress, msg.value, amount, fee, block.timestamp);
    }

    function sell(address tokenAddress, uint256 amount) external nonReentrant {
        require(
            tokens[tokenAddress] == TokenState.FUNDING,
            "Token is not funding"
        );
        require(amount > 0, "Amount should be greater than zero");
        Token token = Token(tokenAddress);
        uint256 receivedETH = bondingCurve.getFundsReceived(
            token.totalSupply(),
            amount
        );
        // calculate fee
        uint256 _fee = calculateFee(receivedETH, feePercent);
        receivedETH -= _fee;
        fee += _fee;
        token.burn(msg.sender, amount);
        collateral[tokenAddress] -= receivedETH;
        // send ether
        //slither-disable-next-line arbitrary-send-eth
        (bool success, ) = msg.sender.call{value: receivedETH}(new bytes(0));
        require(success, "ETH send failed");

        emit TokenSell(tokenAddress, amount, receivedETH, fee, block.timestamp);
    }

    // Internal functions

    function createLiquilityPool(
        address tokenAddress
    ) internal returns (address) {
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2Factory);
        IUniswapV2Router01 router = IUniswapV2Router01(uniswapV2Router);

        address pair = factory.createPair(tokenAddress, router.WETH());
        return pair;
    }

    function addLiquidity(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 ethAmount
    ) internal returns (uint256) {
        Token token = Token(tokenAddress);
        IUniswapV2Router01 router = IUniswapV2Router01(uniswapV2Router);
        token.approve(uniswapV2Router, tokenAmount);
        //slither-disable-next-line arbitrary-send-eth
        (, , uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            tokenAddress,
            tokenAmount,
            tokenAmount,
            ethAmount,
            address(this),
            block.timestamp
        );
        return liquidity;
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

    function burnAllAndReleaseWinner(
        address tokenAddress
    ) external onlyOwner {
        uint256 winnerCollateral = collateral[tokenAddress];

        for (uint i = 0; i < totalTokensAddresses; i++) {
            address _tokenAddress = tokensAddresses[i];

            if (tokensAddresses[i] != tokenAddress) {
                Token token = Token(_tokenAddress);
                uint256 _totalSupply = token.totalSupply();
                token.burn(address(this), _totalSupply);
                winnerCollateral += collateral[_tokenAddress];
                collateral[_tokenAddress] = 0;
            }
        }

        Token token = Token(tokenAddress);
        token.mint(address(this), INITIAL_SUPPLY);

        // address pair = createLiquilityPool(tokenAddress);

        // uint256 liquidity = addLiquidity(
        //     tokenAddress,
        //     INITIAL_SUPPLY,
        //     winnerCollateral
        // );

        // burnLiquidityToken(pair, liquidity);

        // tokens[tokenAddress] = TokenState.TRADING;

        collateral[tokenAddress] = 0;

        emit TokenLiqudityAdded(tokenAddress, block.timestamp);
    }
}
