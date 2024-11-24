pragma solidity >=0.8.26;

import "forge-std/Test.sol";
import "@contracts/BancorBondingCurve.sol";
import {UD60x18, ud, convert, unwrap, pow, add, mul, sub, div, convert} from "@prb/math/src/UD60x18.sol";

contract BancorBondingCurveTest is Test {
    BancorBondingCurve internal linearCurve;
    BancorBondingCurve internal quadraticCurve;

    function setUp() public {
        // n=1, m=2
        linearCurve = new BancorBondingCurve(SLOPE_SCALE * 2.0, MAX_WEIGHT / (1 + 1));
        // n=2, m=0.5
        quadraticCurve = new BancorBondingCurve((SLOPE_SCALE * 1) / 2, MAX_WEIGHT / (2 + 1));
    }

    uint256 internal supply = 1000 ether;
    uint256 internal p = 10 ether;
    uint256 internal k = 100 ether;

    function test_BuySellEquivalence_Linear() public view {
        uint256 bEstimated = unwrap(mul(ud(supply), ud(supply)));
        uint256 b = linearCurve.computePriceForMinting(0, 0, supply);
        assertApproxEqRel(b, bEstimated, 0.0001 ether, "b!=bEstimated");
        uint256 mintingAmount = linearCurve.computeMintingAmountFromPrice(b, supply, p);
        uint256 burningAmount = linearCurve.computeBurningAmountFromRefund(b + p, supply + mintingAmount, p);
        assertApproxEqRel(mintingAmount, burningAmount, 0.0001 ether, "mintingAmount!=burningAmount");
        uint256 price = linearCurve.computePriceForMinting(b, supply, k);
        uint256 refund = linearCurve.computeRefundForBurning(b + price, supply + k, k);
        assertApproxEqRel(price, refund, 0.0001 ether, "price!=refund");
        uint256 refundForMintAmount = linearCurve.computeRefundForBurning(b + p, supply + mintingAmount, mintingAmount);
        assertApproxEqRel(p, refundForMintAmount, 0.0001 ether, "p!=refundForMintAmount");
        uint256 priceForBurningAmount = linearCurve.computePriceForMinting(b, supply, burningAmount);
        assertApproxEqRel(p, priceForBurningAmount, 0.0001 ether, "p!=priceForBurningAmount");
    }

    function test_BuySellEquivalence_Quadratic() public view {
        uint256 bEstimated = unwrap(div(pow(ud(supply), convert(3)), convert(6)));
        uint256 b = quadraticCurve.computePriceForMinting(0, 0, supply);
        assertApproxEqRel(b, bEstimated, 0.0001 ether, "b!=bEstimated");
        uint256 mintingAmount = quadraticCurve.computeMintingAmountFromPrice(b, supply, p);
        uint256 burningAmount = quadraticCurve.computeBurningAmountFromRefund(b + p, supply + mintingAmount, p);
        assertApproxEqRel(mintingAmount, burningAmount, 0.0001 ether, "mintingAmount!=burningAmount");
        uint256 price = quadraticCurve.computePriceForMinting(b, supply, k);
        uint256 refund = quadraticCurve.computeRefundForBurning(b + price, supply + k, k);
        assertApproxEqRel(price, refund, 0.0001 ether, "price!=refund");
        uint256 refundForMintAmount = quadraticCurve.computeRefundForBurning(b + p, supply + mintingAmount, mintingAmount);
        assertApproxEqRel(p, refundForMintAmount, 0.0001 ether, "p!=refundForMintAmount");
        uint256 priceForBurningAmount = quadraticCurve.computePriceForMinting(b, supply, burningAmount);
        assertApproxEqRel(p, priceForBurningAmount, 0.0001 ether, "p!=priceForBurningAmount");
    }

    function test_linearCurveExpectedValues() public view {
        uint256 b = linearCurve.computePriceForMinting(0, 0, supply);
        uint256 price = linearCurve.computePriceForMinting(b, supply, k);
        console.log("(supply + k) * (supply + k) = %s", (supply + k) * (supply + k));
        console.log("supply * supply", supply * supply);
        uint256 integral = unwrap(sub(pow(add(ud(supply), ud(k)), convert(2)), pow(ud(supply), convert(2))));
        assertApproxEqRel(price, integral, 0.0001 ether, "price!=integral");
    }

    function test_quadraticCurveExpectedValues() public view {
        uint256 b = quadraticCurve.computePriceForMinting(0, 0, supply);
        uint256 price = quadraticCurve.computePriceForMinting(b, supply, k);
        console.log("(supply + k) * (supply + k) * (supply + k) / 6 = %s", (supply + k) * (supply + k) * (supply + k) / 6);
        console.log("supply * supply * supply / 6 = %s", supply * supply * supply / 6);
        uint256 integral = unwrap(div(sub(pow(add(ud(supply), ud(k)), convert(3)), pow(ud(supply), convert(3))), convert(6)));
        assertApproxEqRel(price, integral, 0.0001 ether, "price!=integral");
    }

    function test_CumulativeEquivalence_Linear() public view {
        uint256 s0 = supply / 4;
        uint256 p0 = linearCurve.computePriceForMinting(0, 0, s0);
        uint256 p1 = linearCurve.computePriceForMinting(p0, s0, s0);
        uint256 p2 = linearCurve.computePriceForMinting(p0 + p1, s0 * 2, s0);
        uint256 p3 = linearCurve.computePriceForMinting(p0 + p1 + p2, s0 * 3, s0);
        uint256 pall = linearCurve.computePriceForMinting(0, 0, supply);
        console.log("p0", p0);
        console.log("p1", p1);
        console.log("p2", p2);
        console.log("p3", p3);
        console.log("s0", s0);
        console.log("pall", pall);
        assertApproxEqRel(pall, p0 + p1 + p2 + p3, 0.0001 ether, "pall!=p0+p1+p2+p3");
        //        assertEq(pall, p0 + p1, "pall!=p0+p1");
    }
}
