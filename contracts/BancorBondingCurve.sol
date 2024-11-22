pragma solidity ^0.8.26;

import "./BancorFormula.sol";

uint256 constant SLOPE_SCALE = 10000;

// based on https://medium.com/relevant-community/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a
contract BancorBondingCurve is BancorFormula {
    uint256 public immutable slope;

    uint32 public immutable reserveRatio;

    // reserveRatio = connectorWeight, connectorWeight / MAX_WEIGHT represents  1 / (n+1). Given MAX_WEIGHT=1000000 (used as a scaling factor here), it means connectorWeight  = 1000000 / (n+1)
    // so for n=1, connectorWeight=500000; n=2, connectorWeight=333333, and so on
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
//        return calculateSaleReturn(supply + k, b, reserveRatio, k);
        uint256 pp = calculateSaleReturn(supply + k, b, reserveRatio, k);
        p = b * pp / (b - pp);
    }

    // buy function
    function computeMintingAmountFromPrice(uint256 b, uint256 supply, uint256 p) public view returns (uint256 k) {
        if (supply == 0) {
            uint256 result;
            uint8 precision;
            (result, precision) = power(p * MAX_WEIGHT * SLOPE_SCALE, reserveRatio * slope, reserveRatio, MAX_WEIGHT);
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
        uint256 k0 = calculatePurchaseReturn(supply, b - p, reserveRatio, p);
        k = (k0 * supply) / (k0 + supply);
    }
}
