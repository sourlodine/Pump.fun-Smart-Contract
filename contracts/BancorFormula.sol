pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud, div, sub, add, pow, mul, eq, isZero, gt, convert} from "@prb/math/src/UD60x18.sol";

uint32 constant MAX_WEIGHT = 1000000;

/**
 * @title Bancor formula
 * @dev This new version is developed separately and fixed errors resulted from inaccurate power functions from previous versions.
 * The previous version was developed by Slava Balasanov, modified from formula originally developed by Bancor.
 * https://github.com/bancorprotocol/contracts
 * Licensed to the Apache Software Foundation (ASF) under one or more contributor license agreements;
 * and to You under the Apache License, Version 2.0. "
 */
contract BancorFormula {
    string public constant version = "0.4";

    error WeightExceeded();
    error SellAmountExceededSupply();
    error ZeroSupply();
    error ZeroBalance();
    error ZeroWeight();

    /**
     * @dev given a token supply, contract balance, curve weight and a deposit amount (in native token),
     * calculates the amount of contract tokens to be minted
     *
     * Formula:
     * k = s * ((1 + p / b) ^ (w / 1000000) - 1)
     *
     * @param s    token total supply, in 18-decimal fixed point format (UD60x18)
     * @param b    current total contract balance,  in 18-decimal fixed point format (UD60x18)
     * @param w    curve weight, represented in 6-decimal fixed point, with the range of 1 - 1000000
     * @param p    amount of native token to be deposited, in 18-decimal fixed point format
     *
     * @return k   the amount of contract tokens to be minted for the given deposit, in 18-decimal fixed point format (UD60x18)
     */
    function calculatePurchaseReturn(
        UD60x18 s,
        UD60x18 b,
        uint32 w,
        UD60x18 p
    ) internal view returns (UD60x18) {
        if (isZero(s)) {
            revert ZeroSupply();
        }
        if (isZero(b)) {
            revert ZeroBalance();
        }
        if (w == 0) {
            revert ZeroWeight();
        }
        if (w > MAX_WEIGHT) {
            revert WeightExceeded();
        }
        if (isZero(p)) {
            return ud(0);
        }
        if (w == MAX_WEIGHT) {
            UD60x18 r0 = div(p, b);
            return mul(s, r0);
        }
        UD60x18 pp = add(p, b);
        UD60x18 base = div(pp, b);
        UD60x18 exponent = div(convert(w), convert(MAX_WEIGHT));
        UD60x18 r = pow(base, exponent);
        UD60x18 sp = mul(s, r);
        return sub(sp, s);
    }

    /**
     * @dev given a token supply, connector balance, weight and a sell amount (in the main token),
     * calculates the return for a given conversion (in the connector token)
     *
     * p = b * (1 - (1 - k / s) ^ (1 / (w / 1000000)))
     *
     * @param s    token total supply, in 18-decimal fixed point format (UD60x18)
     * @param b    current total contract balance,  in 18-decimal fixed point format (UD60x18)
     * @param w    curve weight, represented in 6-decimal fixed point, with the range of 1 - 1000000
     * @param k    amount of contract token to be sold, in 18-decimal fixed point format
     *
     * @return p    the amount of native tokens to be returned for the amount of contract token to be sold, in 18-decimal fixed point format (UD60x18)
     */
    function calculateSaleReturn(UD60x18 s, UD60x18 b, uint32 w, UD60x18 k) internal view returns (UD60x18) {
        if (isZero(s)) {
            revert ZeroSupply();
        }
        if (isZero(b)) {
            revert ZeroBalance();
        }
        if (w == 0) {
            revert ZeroWeight();
        }
        if (w > MAX_WEIGHT) {
            revert WeightExceeded();
        }
        if (gt(k, s)) {
            revert SellAmountExceededSupply();
        }
        if (isZero(k)) {
            return ud(0);
        }
        if (eq(k, s)) {
            return b;
        }
        if (w == MAX_WEIGHT) {
            UD60x18 r0 = div(k, s);
            return mul(b, r0);
        }
        UD60x18 sp = sub(s, k);
        UD60x18 exponent = div(convert(MAX_WEIGHT), convert(w));
        UD60x18 base = div(sp, s);
        UD60x18 r = pow(base, exponent);
        UD60x18 bp = mul(b, r);
        return sub(b, bp);
        //        another way, potentially more stable, but needs more testing to confirm
        //        UD60x18 baseInversed = div(s, sp);
        //        UD60x18 rInversed = pow(baseInversed, exponent);
        //        UD60x18 bpInversed = mul(b, rInversed);
        //        return div(sub(b, bpInversed), rInvesred)
    }
}
