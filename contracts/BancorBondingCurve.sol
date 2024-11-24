pragma solidity ^0.8.26;

import "./BancorFormula.sol";

uint256 constant SLOPE_SCALE = 10000;
import {UD60x18, ud, convert, unwrap, pow, add, mul, sub, div, convert} from "@prb/math/src/UD60x18.sol";

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
    function computePriceForMinting(uint256 b, uint256 s, uint256 k) public view returns (uint256 p) {
        UD60x18 sw = ud(s);
        UD60x18 bw = ud(b);
        UD60x18 kw = ud(k);
        if (s == 0) {
            UD60x18 wi = div(convert(MAX_WEIGHT), convert(reserveRatio));
            UD60x18 r = pow(kw, wi);
            UD60x18 m = div(convert(slope), convert(SLOPE_SCALE));
            UD60x18 pw0 = div(mul(r, m), wi);
            return unwrap(pw0);
        }
        UD60x18 ppw = calculateSaleReturn(add(sw, kw), bw, reserveRatio, kw);
        UD60x18 pw = div(mul(bw, ppw), sub(bw, ppw));
        p = unwrap(pw);
    }

    // buy function
    function computeMintingAmountFromPrice(uint256 b, uint256 s, uint256 p) public view returns (uint256 k) {
        UD60x18 sw = ud(s);
        UD60x18 bw = ud(b);
        UD60x18 pw = ud(p);
        if (s == 0) {
            UD60x18 ww = div(convert(reserveRatio), convert(MAX_WEIGHT));
            UD60x18 mw = div(convert(slope), convert(SLOPE_SCALE));
            UD60x18 base = div(div(pw, ww), mw);
            UD60x18 kw0 = pow(base, ww);
            return unwrap(kw0);
        }
        UD60x18 kw = calculatePurchaseReturn(sw, bw, reserveRatio, pw);
        k = unwrap(kw);
    }

    // sell function
    function computeRefundForBurning(uint256 b, uint256 s, uint256 k) public view returns (uint256 p) {
        if (s == k) {
            return b;
        }
        UD60x18 sw = ud(s);
        UD60x18 bw = ud(b);
        UD60x18 kw = ud(k);
        UD60x18 pw = calculateSaleReturn(sw, bw, reserveRatio, kw);
        p = unwrap(pw);
    }

    function computeBurningAmountFromRefund(uint256 b, uint256 s, uint256 p) public view returns (uint256 k) {
        if (b == p) {
            return s;
        }
        UD60x18 sw = ud(s);
        UD60x18 bw = ud(b);
        UD60x18 pw = ud(p);
        UD60x18 k0w = calculatePurchaseReturn(sw, sub(bw, pw), reserveRatio, pw);
        k = unwrap(div(mul(k0w, sw), add(k0w, sw)));
    }
}
