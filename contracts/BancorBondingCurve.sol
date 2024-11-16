pragma solidity ^0.8.26;

import "./BancorFormula.sol";

// based on https://medium.com/relevant-community/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a
contract BancorBondingCurve is BancorFormula {
    uint256 public immutable slope;
    uint32 public immutable reserveRatio;

    // reserveRatio = connectorWeight, but is scaled by MAX_WEIGHT (1000000)
    // also note that unscaled reserveRatio = 1 / (n+1), so a reserveRatio 1000000 means n=0, reserveRatio=2000000 means n=1, and so on
    // slope (denoted as m in the article) is only relevant when supply = 0. When supply is non-zero, the price for minting k tokens can be fully determined by current balance and supply
    constructor(uint256 _slope, uint32 _reserveRatio) {
        slope = _slope;
        reserveRatio = _reserveRatio;
    }

    // buy function
    function computePriceForMinting(uint256 b, uint256 supply, uint256 k) public view returns (uint256 p) {
        if (supply == 0) {
            uint256 result;
            uint8 precision;
            (result, precision) = power(k, 1, MAX_WEIGHT, reserveRatio);
            return ((slope * reserveRatio) / MAX_WEIGHT) >> precision;
        }
        return calculateSaleReturn(supply + k, b, reserveRatio, k);
    }

    // buy function
    function computeMintingAmountFromPrice(uint256 b, uint256 supply, uint256 p) public view returns (uint256 k) {
        if (supply == 0) {
            uint256 result;
            uint8 precision;
            (result, precision) = power(p * MAX_WEIGHT, reserveRatio * slope, reserveRatio, MAX_WEIGHT);
            return result >> precision;
        }
        return calculatePurchaseReturn(supply, b, reserveRatio, p);
    }

    // sell function
    function computeRefundForBurning(uint256 b, uint256 supply, uint256 k) public view returns (uint256 p) {
        if (supply == k) {
            return b;
        }
        return calculateSaleReturn(supply, b, reserveRatio, k);
    }

    function computeBurningAmountFromRefund(uint256 b, uint256 supply, uint256 p) public view returns (uint256 k) {
        if (b == p) {
            return supply;
        }
        return calculatePurchaseReturn(supply, b - p, reserveRatio, p);
    }
}
