// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./Pair.sol";

contract Factory is ReentrancyGuard {
    address private owner;

    address private _feeTo;

    mapping (address => mapping (address => address)) private pair;

    address[] private pairs;

    uint private constant fee = 5;

    constructor(address fee_to) {
        owner = msg.sender;

        require(fee_to != address(0), "Zero addresses are not allowed.");

        _feeTo = fee_to;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function.");

        _;
    }

    event PairCreated(address indexed tokenA, address indexed tokenB, address pair, uint);

    function _createPair(address tokenA, address tokenB) private returns (address) {
        require(tokenA != address(0), "Zero addresses are not allowed.");
        require(tokenB != address(0), "Zero addresses are not allowed.");

        Pair _pair = new Pair(address(this), tokenA, tokenB);

        pair[tokenA][tokenB] = address(_pair);
        pair[tokenB][tokenA] = address(_pair);

        pairs.push(address(_pair));

        uint n = pairs.length;

        emit PairCreated(tokenA, tokenB, address(_pair), n);

        return address(_pair);
    }

    function createPair(address tokenA, address tokenB) external nonReentrant returns (address) {
        address _pair = _createPair(tokenA, tokenB);

        return _pair;
    }

    function getPair(address tokenA, address tokenB) public view returns (address) {
        return pair[tokenA][tokenB];
    }

    function allPairs(uint n) public view returns (address)  {
        return pairs[n];
    }

    function allPairsLength() public view returns (uint) {
        return pairs.length;
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

    function txFee() public pure returns (uint) {
        return fee;
    }
}