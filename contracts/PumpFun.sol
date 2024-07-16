// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./Factory.sol";
import "./Pair.sol";
import "./Router.sol";
import "./ERC20.sol";

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

contract PumpFun is ReentrancyGuard {
    receive() external payable {}
    
    address private owner;

    Factory private factory;

    Router private router;

    address private _feeTo;

    uint256 private fee;

    uint private constant lpFee = 5;

    uint256 private constant mcap = 100_000 ether;

    IUniswapV2Router02 private uniswapV2Router;

    struct Profile {
        address user;
        Token[] tokens;
    }

    struct Token {
        address creator;
        address token;
        address pair;
        Data data;
        string description;
        string image;
        string twitter;
        string telegram;
        string youtube;
        string website;
        bool trading;
        bool tradingOnUniswap;
    }

    struct Data {
        address token;
        string name;
        string ticker;
        uint256 supply;
        uint256 price;
        uint256 marketCap;
        uint256 liquidity;
        uint256 _liquidity;
        uint256 volume;
        uint256 volume24H;
        uint256 prevPrice;
        uint256 lastUpdated;
    }

    mapping (address => Profile) public profile;

    Profile[] public profiles;

    mapping (address => Token) public token;

    Token[] public tokens;

    event Launched(address indexed token, address indexed pair, uint);

    event Deployed(address indexed token, uint256 amount0, uint256 amount1);

    constructor(address factory_, address router_, address fee_to, uint256 _fee) {
        owner = msg.sender;

        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(router_ != address(0), "Zero addresses are not allowed.");
        require(fee_to != address(0), "Zero addresses are not allowed.");
    
        factory = Factory(factory_);

        router = Router(router_);

        _feeTo = fee_to;

        fee = (_fee * 1 ether) / 1000;

        uniswapV2Router = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function.");

        _;
    }

    function createUserProfile(address _user) private returns (bool) {
        require(_user != address(0), "Zero addresses are not allowed.");

        Token[] memory _tokens;

        Profile memory _profile = Profile({
            user: _user,
            tokens: _tokens
        });

        profile[_user] = _profile;

        profiles.push(_profile);

        return true;
    }

    function checkIfProfileExists(address _user) private view returns (bool) {
        require(_user != address(0), "Zero addresses are not allowed.");

        bool exists = false;

        for(uint i = 0; i < profiles.length; i++) {
            if(profiles[i].user == _user) {
                return true;
            }
        }

        return exists;
    }

    function _approval(address _user, address _token, uint256 amount) private returns (bool) {
        require(_user != address(0), "Zero addresses are not allowed.");
        require(_token != address(0), "Zero addresses are not allowed.");

        ERC20 token_ = ERC20(_token);

        token_.approve(_user, amount);

        return true;
    }

    function approval(address _user, address _token, uint256 amount) external nonReentrant returns (bool) {
        bool approved = _approval(_user, _token, amount);

        return approved;
    }

    function launchFee() public view returns (uint256) {
        return fee;
    }

    function updateLaunchFee(uint256 _fee) public returns (uint256) {
        fee = _fee;

        return _fee;
    }

    function liquidityFee() public pure returns (uint256) {
        return lpFee;
    }

    function feeTo() public view returns (address) {
        return _feeTo;
    }

    function feeToSetter() public view returns (address) {
        return owner;
    }

    function setFeeTo(address fee_to) public onlyOwner{
        require(fee_to != address(0), "Zero addresses are not allowed.");

        _feeTo = fee_to;
    }

    function marketCapLimit() public pure returns (uint256) {
        return mcap;
    }

    function getUserTokens() public view returns (Token[] memory) {
        require(checkIfProfileExists(msg.sender), "User Profile dose not exist.");

        Profile memory _profile = profile[msg.sender];

        return _profile.tokens;
    }

    function getTokens() public view returns (Token[] memory) {
        return tokens;
    }

    function launch(string memory _name, string memory _ticker, string memory desc, string memory img, string[4] memory urls, uint256 _supply, uint maxTx) public payable nonReentrant returns (address, address, uint) {
        require(msg.value >= fee, "Insufficient amount sent.");

        ERC20 _token = new ERC20(_name, _ticker, _supply, maxTx);

        address weth = router.WETH();

        address _pair = factory.createPair(address(_token), weth);

        Pair pair_ = Pair(payable(_pair));

        uint256 supply = _supply * 10 ** _token.decimals();

        bool approved = _approval(address(router), address(_token), supply);
        require(approved);

        uint256 liquidity = (lpFee * msg.value) / 100;
        uint256 value = msg.value - liquidity;

        router.addLiquidityETH{value: liquidity}(address(_token), supply);

        Data memory _data = Data({
            token: address(_token),
            name: _name,
            ticker: _ticker,
            supply: supply,
            price: supply / pair_.MINIMUM_LIQUIDITY(),
            marketCap: pair_.MINIMUM_LIQUIDITY(),
            liquidity: liquidity * 2,
            _liquidity: pair_.MINIMUM_LIQUIDITY() * 2,
            volume: 0,
            volume24H: 0,
            prevPrice: supply / pair_.MINIMUM_LIQUIDITY(),
            lastUpdated: block.timestamp
        });

        Token memory token_ = Token({
            creator: msg.sender,
            token: address(_token),
            pair: _pair,
            data: _data,
            description: desc,
            image: img,
            twitter: urls[0],
            telegram: urls[1],
            youtube: urls[2],
            website: urls[3],
            trading: true,
            tradingOnUniswap: false
        });

        token[address(_token)] = token_;

        tokens.push(token_);

        bool exists = checkIfProfileExists(msg.sender);

        if(exists) {
            Profile storage _profile = profile[msg.sender];

            _profile.tokens.push(token_);
        } else {
            bool created = createUserProfile(msg.sender);

            if(created) {
                Profile storage _profile = profile[msg.sender];

                _profile.tokens.push(token_);
            }
        }

        (bool os, ) = payable(_feeTo).call{value: value}("");
        require(os);

        uint n = tokens.length;

        emit Launched(address(_token), _pair, n);

        return (address(_token), _pair, n);
    }

    function swapTokensForETH(uint256 amountIn, address tk, address to, address referree) public returns (bool) {
        require(tk != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");
        require(referree != address(0), "Zero addresses are not allowed.");

        address _pair = factory.getPair(tk, router.WETH());

        Pair pair = Pair(payable(_pair));

        (uint256 reserveA, uint256 reserveB , uint256 _reserveB) = pair.getReserves();

        (uint256 amount0In, uint256 amount1Out) = router.swapTokensForETH(amountIn, tk, to, referree);

        uint256 newReserveA = reserveA + amount0In;
        uint256 newReserveB = reserveB - amount1Out;
        uint256 _newReserveB = _reserveB - amount1Out;
        uint256 duration = block.timestamp - token[tk].data.lastUpdated;

        uint256 _liquidity = _newReserveB * 2;
        uint256 liquidity = newReserveB * 2;
        uint256 mCap = (token[tk].data.supply * _newReserveB) / newReserveA;
        uint256 price = newReserveA / _newReserveB;
        uint256 volume = duration > 86400 ? amount1Out : token[tk].data.volume24H + amount1Out;
        uint256 _price = duration > 86400 ? token[tk].data.price : token[tk].data.prevPrice;

        token[tk].data.price = price;
        token[tk].data.marketCap = mCap;
        token[tk].data.liquidity = liquidity;
        token[tk].data._liquidity = _liquidity;
        token[tk].data.volume = token[tk].data.volume + amount1Out;
        token[tk].data.volume24H = volume;
        token[tk].data.prevPrice = _price;
        
        if(duration > 86400) {
            token[tk].data.lastUpdated = block.timestamp;
        }

        for (uint i = 0; i < tokens.length; i++) {
            if(tokens[i].token == tk) {
                tokens[i].data.price = price;
                tokens[i].data.marketCap = mCap;
                tokens[i].data.liquidity = liquidity;
                tokens[i].data._liquidity = _liquidity;
                tokens[i].data.volume = token[tk].data.volume + amount1Out;
                tokens[i].data.volume24H = volume;
                tokens[i].data.prevPrice = _price;

                if(duration > 86400) {
                    tokens[i].data.lastUpdated = block.timestamp;
                }
            }
        }

        return true;
    }

    function swapETHForTokens(address tk, address to, address referree) public payable returns (bool) {
        require(tk != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");
        require(referree != address(0), "Zero addresses are not allowed.");

        address _pair = factory.getPair(tk, router.WETH());

        Pair pair = Pair(payable(_pair));

        (uint256 reserveA, uint256 reserveB , uint256 _reserveB) = pair.getReserves();

        (uint256 amount1In, uint256 amount0Out) = router.swapETHForTokens{value: msg.value}(tk, to, referree);

        uint256 newReserveA = reserveA - amount0Out;
        uint256 newReserveB = reserveB + amount1In;
        uint256 _newReserveB = _reserveB + amount1In;
        uint256 duration = block.timestamp - token[tk].data.lastUpdated;

        uint256 _liquidity = _newReserveB * 2;
        uint256 liquidity = newReserveB * 2;
        uint256 mCap = (token[tk].data.supply * _newReserveB) / newReserveA;
        uint256 price = newReserveA / _newReserveB;
        uint256 volume = duration > 86400 ? amount1In : token[tk].data.volume24H + amount1In;
        uint256 _price = duration > 86400 ? token[tk].data.price : token[tk].data.prevPrice;

        token[tk].data.price = price;
        token[tk].data.marketCap = mCap;
        token[tk].data.liquidity = liquidity;
        token[tk].data._liquidity = _liquidity;
        token[tk].data.volume = token[tk].data.volume + amount1In;
        token[tk].data.volume24H = volume;
        token[tk].data.prevPrice = _price;
        
        if(duration > 86400) {
            token[tk].data.lastUpdated = block.timestamp;
        }

        for (uint i = 0; i < tokens.length; i++) {
            if(tokens[i].token == tk) {
                tokens[i].data.price = price;
                tokens[i].data.marketCap = mCap;
                tokens[i].data.liquidity = liquidity;
                tokens[i].data._liquidity = _liquidity;
                tokens[i].data.volume = token[tk].data.volume + amount1In;
                tokens[i].data.volume24H = volume;
                tokens[i].data.prevPrice = _price;

                if(duration > 86400) {
                    tokens[i].data.lastUpdated = block.timestamp;
                }
            }
        }

        return true;
    }

    function deploy(address tk) public onlyOwner nonReentrant {
        require(tk != address(0), "Zero addresses are not allowed.");

        address weth = router.WETH();

        address pair = factory.getPair(tk, weth);

        ERC20 token_ = ERC20(tk);

        token_.excludeFromMaxTx(pair);

        Token storage _token = token[tk];

        (uint256 amount0, uint256 amount1) = router.removeLiquidityETH(tk, 100, address(this));

        Data memory _data = Data({
            token: tk,
            name: token[tk].data.name,
            ticker: token[tk].data.ticker,
            supply: token[tk].data.supply,
            price: 0,
            marketCap: 0,
            liquidity: 0,
            _liquidity: 0,
            volume: 0,
            volume24H: 0,
            prevPrice: 0,
            lastUpdated: block.timestamp
        });

        _token.data = _data;

        for (uint i = 0; i < tokens.length; i++) {
            if(tokens[i].token == tk) {
                tokens[i].data = _data;
            }
        }

        openTradingOnUniswap(tk);

        _token.trading = false;
        _token.tradingOnUniswap = true;

        emit Deployed(tk, amount0, amount1);
    }

    function openTradingOnUniswap(address tk) private {
        require(tk != address(0), "Zero addresses are not allowed.");

        ERC20 token_ = ERC20(tk);

        Token storage _token = token[tk];

        require(_token.trading && !_token.tradingOnUniswap, "trading is already open");

        bool approved = _approval(address(uniswapV2Router), tk, token_.balanceOf(address(this)));
        require(approved, "Not approved.");

        address uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(tk, uniswapV2Router.WETH());

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            tk,
            token_.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );

        ERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
    }
}