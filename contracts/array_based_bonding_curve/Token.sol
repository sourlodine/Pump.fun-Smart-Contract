
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    address public tokenFactory;

    constructor(string memory name, string memory symbol, address _tokenFactory) ERC20(name, symbol) {
        require(_tokenFactory != address(0), "Bonding curve address cannot be zero");
        tokenFactory = _tokenFactory;
    }

    function updateBondingCurve(address _newTokenFactory) external onlyOwner {
        require(_newTokenFactory != address(0), "New bonding curve address cannot be zero");
        tokenFactory = _newTokenFactory;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == tokenFactory, "Only bonding curve can mint");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == tokenFactory, "Only bonding curve can burn");
        _burn(from, amount);
    }
}