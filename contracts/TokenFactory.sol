// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./Token.sol";

interface IPumpFun {
    function createPool(address token, uint256 amount) external payable;
    function getCreateFee() external view returns (uint256);
}

contract TokenFactory {
    uint256 public currentTokenIndex = 0;
    uint256 public immutable INITIAL_AMOUNT = 10 ** 27;

    address public contractAddress;
    address public taxAddress = "";

    struct TokenStructure {
        address tokenAddress;
        string tokenName;
        string tokenSymbol;
        uint256 totalSupply;
    }

    TokenStructure[] public tokens;

    constructor() {}

    function deployERC20Token(
        string memory name,
        string memory ticker
    ) public payable {
        Token token = new Token(name, ticker, INITIAL_AMOUNT);
        tokens.push(
            TokenStructure(address(token), name, ticker, INITIAL_AMOUNT)
        );

        token.approve(contractAddress, INITIAL_AMOUNT);
        uint256 balance = IPumpFun(contractAddress).getCreateFee();

        require(msg.value >= balance, "Input Balance Should Be larger");
        IPumpFun(contractAddress).createPool{value: balance}(
            address(token),
            INITIAL_AMOUNT
        );
    }

    function setPoolAddress(address newAddr) public {
        require(newAddr != address(0), "Non zero Address");
        contractAddress = newAddr;
    }
}
