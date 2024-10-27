// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract ConstantBondingCurve {
    uint256 public constant FUNDING_SUPPLY = 800_000_000 ether;
    uint256 public constant FUNDING_GOAL = 20 ether;

    function calculateBuyReturn(
        uint256 ethAmount
    ) public pure returns (uint256) {
        return (ethAmount * FUNDING_SUPPLY) / FUNDING_GOAL;
    }

    function calculateSellReturn(
        uint256 tokenAmount
    ) public pure returns (uint256) {
        return (tokenAmount * FUNDING_GOAL) / FUNDING_SUPPLY;
    }
}
