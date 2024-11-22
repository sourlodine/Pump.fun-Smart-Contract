pragma solidity >=0.8.26;

import "forge-std/Test.sol";
import "@contracts/BancorBondingCurve.sol";

contract BancorBondingCurveTest is Test {
    BancorBondingCurve internal linearCurve;
    BancorBondingCurve internal quadraticCurve;

    function setUp() public {
        // n=1, m=2
        linearCurve = new BancorBondingCurve(SLOPE_SCALE * 2.0, MAX_WEIGHT / (1 + 1));
        // n=2, m=0.5
        quadraticCurve = new BancorBondingCurve((SLOPE_SCALE * 1) / 2, MAX_WEIGHT * (2 + 1));
    }

    function test_BuySellEquivalenceLinear() public {
        uint256 b = 1 ether;
        uint256 supply = 1000 ether;
        uint256 p = 0.5 ether;
        //        console.log(address(linearCurve));
        uint256 mintingAmount = linearCurve.computeMintingAmountFromPrice(b, supply, p);
        uint256 burningAmount = linearCurve.computeBurningAmountFromRefund(b + p, supply + mintingAmount, p);
        assertEqUint(mintingAmount, burningAmount);
        uint256 k = 50 ether;
        uint256 price = linearCurve.computePriceForMinting(b, supply, k);
        uint256 refund = linearCurve.computeRefundForBurning(b + price, supply + k, k);
        assertEqUint(price, refund);
    }


}
