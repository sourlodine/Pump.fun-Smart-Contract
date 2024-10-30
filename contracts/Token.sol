// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Token is ERC20Upgradeable, OwnableUpgradeable {
    string public uri;

    function initialize(
        string memory name,
        string memory symbol,
        string memory _uri,
        address _owner
    ) public initializer {
        __ERC20_init(name, symbol);
        uri = _uri;
        // __Ownable_init(msg.sender);
        __Ownable_init(_owner);
    }

    function contractURI() public view returns (string memory) {
        return uri;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public onlyOwner {
        _burn(to, amount);
    }
}
