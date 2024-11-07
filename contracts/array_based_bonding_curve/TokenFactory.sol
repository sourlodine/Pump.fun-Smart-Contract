// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BondingCurve.sol";
import "./Token.sol";

contract TokenFactory is Ownable {
    struct Bond {
        uint256 reserveBalance;
        BondingCurve.Step[] steps;
        address creator;
        uint256 createdAt;
    }

    struct TokenInfo {
        string name;
        string symbol;
        address tokenAddress;
        bytes32 nameHash;
        address creator;
    }

    struct TokenInfoWithPrice {
        string name;
        string symbol;
        address tokenAddress;
        uint256 currentPrice;
        uint256 totalSupply;
    }

    BondingCurve public bondingCurve;
    IERC20 public reserveToken;
    TokenInfo[] public tokens;
    mapping(address => Bond) public tokenBond;
    mapping(address => TokenInfo) public tokenInfo;
    mapping(bytes32 => bool) private usedNameHashes;
    mapping(address => address[]) private ownerTokens;

    address public currentWinner;
    uint256 public lastUpdateTime;

    event TokensPurchased(address token, address buyer, uint256 amount, uint256 cost);
    event TokensSold(address token, address seller, uint256 amount, uint256 refund);
    event DailyWinnerUpdated(address winner);
    event TokenAdded(address token, string name, string symbol);

    constructor(address _reserveToken, address _bondingCurve) {
        reserveToken = IERC20(_reserveToken);
        bondingCurve = BondingCurve(_bondingCurve);
    }

    function createToken(string memory name, string memory symbol, uint256[] memory _supplies, uint256[] memory _prices) external onlyOwner {
        require(_supplies.length == _prices.length, "Supplies and prices must have the same length");
        require(_supplies.length > 0, "Must provide at least one step");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        
        bytes32 nameHash = keccak256(bytes(name));
        require(!usedNameHashes[nameHash], "Name already exists");

        Token newToken = new Token(name, symbol, address(this));
        address tokenAddress = address(newToken);
        
        TokenInfo memory newTokenInfo = TokenInfo(name, symbol, tokenAddress, nameHash, msg.sender);
        tokens.push(newTokenInfo);
        tokenInfo[tokenAddress] = newTokenInfo;
        ownerTokens[msg.sender].push(tokenAddress);
        
        Bond storage newBond = tokenBond[tokenAddress];
        newBond.creator = msg.sender;
        newBond.createdAt = block.timestamp;
        
        for (uint256 i = 0; i < _supplies.length; i++) {
            newBond.steps.push(BondingCurve.Step(_supplies[i], _prices[i]));
        }

        emit TokenAdded(tokenAddress, name, symbol);
    }

    function buy(address token, uint256 amount) external {
        uint256 supply = IERC20(token).totalSupply();
        uint256 cost = bondingCurve.getCost(tokenBond[token].steps, supply, amount);
        
        reserveToken.transferFrom(msg.sender, address(this), cost);
        tokenBond[token].reserveBalance += cost;
        Token(token).mint(msg.sender, amount);
        
        emit TokensPurchased(token, msg.sender, amount, cost);
    }

    function sell(address token, uint256 amount) external {
        uint256 supply = IERC20(token).totalSupply();
        uint256 refund = bondingCurve.getRefund(tokenBond[token].steps, supply, amount);
        
        Token(token).burn(msg.sender, amount);
        tokenBond[token].reserveBalance -= refund;
        reserveToken.transfer(msg.sender, refund);
        
        emit TokensSold(token, msg.sender, amount, refund);
    }

    function getTokenList() public view returns (TokenInfo[] memory) {
        return tokens;
    }

    function getTokenListWithPrice() public view returns (TokenInfoWithPrice[] memory) {
        uint256 tokenCount = tokens.length;
        TokenInfoWithPrice[] memory tokenList = new TokenInfoWithPrice[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            address tokenAddress = tokens[i].tokenAddress;
            uint256 supply = IERC20(tokenAddress).totalSupply();
            uint256 price = bondingCurve.getCurrentPrice(tokenBond[tokenAddress].steps, supply);

            tokenList[i] = TokenInfoWithPrice(
                tokens[i].name,
                tokens[i].symbol,
                tokenAddress,
                price,
                supply
            );
        }

        return tokenList;
    }

    function getOwnerTokens(address creator) public view returns (TokenInfoWithPrice[] memory) {
        address[] storage ownerTokenAddresses = ownerTokens[creator];
        TokenInfoWithPrice[] memory result = new TokenInfoWithPrice[](ownerTokenAddresses.length);
        
        for (uint i = 0; i < ownerTokenAddresses.length; i++) {
            TokenInfo memory token = tokenInfo[ownerTokenAddresses[i]];
            uint256 supply = IERC20(token.tokenAddress).totalSupply();
            uint256 price = bondingCurve.getCurrentPrice(tokenBond[token.tokenAddress].steps, supply);
            
            result[i] = TokenInfoWithPrice(
                token.name,
                token.symbol,
                token.tokenAddress,
                price,
                supply
            );
        }
        return result;
    }

    function getTopLiquidityToken(uint256 timestamp) public view returns (address topToken, uint256 maxLiquidity) {
        uint256 targetDate = timestamp == 0 ? block.timestamp : timestamp;

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i].tokenAddress;
            Bond storage bond = tokenBond[token];
            uint256 tokenCreationDay = bond.createdAt - (bond.createdAt % 1 days);
            
            if (tokenCreationDay == targetDate) {
                uint256 liquidity = bond.reserveBalance;
                if (liquidity > maxLiquidity) {
                    maxLiquidity = liquidity;
                    topToken = token;
                }
            }
        }
        return (topToken, maxLiquidity);
    }

    function updateDailyWinner(uint256 timestamp) external onlyOwner {
        require(block.timestamp >= lastUpdateTime + 1 days, "24 hours have not passed");
        (address newWinner, ) = getTopLiquidityToken(timestamp);
        currentWinner = newWinner;
        lastUpdateTime = block.timestamp;
        emit DailyWinnerUpdated(newWinner);
    }

    function getTokenSteps(address token) public view returns (BondingCurve.Step[] memory) {
        return tokenBond[token].steps;
    }

    function getTokenStepCount(address token) public view returns (uint256) {
        return tokenBond[token].steps.length;
    }

    function getTokenStepAt(address token, uint256 index) public view returns (BondingCurve.Step memory) {
        require(index < tokenBond[token].steps.length, "Index out of bounds");
        return tokenBond[token].steps[index];
    }
}