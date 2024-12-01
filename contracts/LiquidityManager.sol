// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Token} from "./Token.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint) external;
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

abstract contract LiquidityManager is IERC721Receiver, Ownable {
    uint24 public constant UNISWAP_FEE = 3000;
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;

    address internal immutable WETH;
    address public nonfungiblePositionManager;
    address public uniswapV3Factory;

    constructor(address _uniswapV3Factory, address _nonfungiblePositionManager, address _weth) Ownable(msg.sender) {
        uniswapV3Factory = _uniswapV3Factory;
        nonfungiblePositionManager = _nonfungiblePositionManager;
        WETH = _weth;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _createLiquilityPool(address tokenAddress) internal returns (address) {
        IUniswapV3Factory factory = IUniswapV3Factory(uniswapV3Factory);

        address pool = factory.createPool(tokenAddress, WETH, UNISWAP_FEE);

        return pool;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function _addLiquidity(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 ethAmount,
        address recipient
    ) internal returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager _nonfungiblePositionManager = INonfungiblePositionManager(nonfungiblePositionManager);

        IUniswapV3Factory factory = IUniswapV3Factory(uniswapV3Factory);
        address poolAddress = factory.getPool(tokenAddress, WETH, UNISWAP_FEE);

        Token token = Token(tokenAddress);
        token.approve(nonfungiblePositionManager, tokenAmount);

        uint256 eth = address(this).balance;
        IWETH(WETH).deposit{value: eth}();
        IWETH(WETH).approve(nonfungiblePositionManager, eth);

        uint160 sqrtPriceX96 = uint160(sqrt((ethAmount * 2 ** 192) / tokenAmount));
        _nonfungiblePositionManager.createAndInitializePoolIfNecessary(tokenAddress, WETH, UNISWAP_FEE, sqrtPriceX96);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: tokenAddress,
            token1: WETH,
            fee: UNISWAP_FEE,
            tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
            tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
            amount0Desired: tokenAmount,
            amount1Desired: ethAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: recipient,
            deadline: block.timestamp
        });

        return _nonfungiblePositionManager.mint(params);
    }
}
