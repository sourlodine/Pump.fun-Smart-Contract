// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract BondingCurve {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    uint256 public immutable A;
    uint256 public immutable B;

    constructor(uint256 _a, uint256 _b) {
        A = _a;
        B = _b;
    }

    // calculate the funds received for selling deltaX tokens
    function getFundsReceived(
        uint256 x0,
        uint256 deltaX
    ) public view returns (uint256 deltaY) {
        uint256 a = A;
        uint256 b = B;
        require(x0 >= deltaX);
        // calculate exp(b*x0), exp(b*x1)
        int256 exp_b_x0 = (int256(b.mulWad(x0))).expWad();
        int256 exp_b_x1 = (int256(b.mulWad(x0 - deltaX))).expWad();

        // calculate deltaY = (a/b)*(exp(b*x0) - exp(b*x1))
        uint256 delta = uint256(exp_b_x0 - exp_b_x1);
        deltaY = a.fullMulDiv(delta, b);
    }

    // calculte the number of tokens that can be purchased for a given amount of funds
    function getAmountOut(
        uint256 x0,
        uint256 deltaY
    ) public view returns (uint256 deltaX) {
        uint256 a = A;
        uint256 b = B;
        // calculate exp(b*x0)
        uint256 exp_b_x0 = uint256((int256(b.mulWad(x0))).expWad());

        // calculate exp(b*x0) + (dy*b/a)
        uint256 exp_b_x1 = exp_b_x0 + deltaY.fullMulDiv(b, a);

        // calculate ln(x1)/b-x0
        deltaX = uint256(int256(exp_b_x1).lnWad()).divWad(b) - x0;
    }
}
