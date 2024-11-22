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
        quadraticCurve = new BancorBondingCurve((SLOPE_SCALE * 1) / 2, MAX_WEIGHT / (2 + 1));
    }

    uint256 internal b = 1 ether;
    uint256 internal supply = 1000 ether;
    uint256 internal p = 0.5 ether;
    uint256 internal k = 50 ether;

    function test_BuySellEquivalence() public view {
        {
            uint256 mintingAmount = linearCurve.computeMintingAmountFromPrice(b, supply, p);
            uint256 burningAmount = linearCurve.computeBurningAmountFromRefund(b + p, supply + mintingAmount, p);
            assertEq(mintingAmount, burningAmount, "mintingAmount!=burningAmount");
            uint256 price = linearCurve.computePriceForMinting(b, supply, k);
            uint256 refund = linearCurve.computeRefundForBurning(b + price, supply + k, k);
            assertEq(price, refund, "price!=refund");
            uint256 refundForMintAmount = linearCurve.computeRefundForBurning(b + p, supply + mintingAmount, mintingAmount);
            assertApproxEqAbs(p, refundForMintAmount, 1 gwei, "p!=refundForMintAmount");
            uint256 priceForBurningAmount = linearCurve.computePriceForMinting(b, supply, burningAmount);
            assertApproxEqAbs(p, priceForBurningAmount, 1 gwei, "p!=priceForBurningAmount");
        }
        {
            uint256 mintingAmount = quadraticCurve.computeMintingAmountFromPrice(b, supply, p);
            uint256 burningAmount = quadraticCurve.computeBurningAmountFromRefund(b + p, supply + mintingAmount, p);
            assertEq(mintingAmount, burningAmount, "mintingAmount!=burningAmount");
            uint256 price = quadraticCurve.computePriceForMinting(b, supply, k);
            uint256 refund = quadraticCurve.computeRefundForBurning(b + price, supply + k, k);
            assertEq(price, refund, "price!=refund");
            uint256 refundForMintAmount = quadraticCurve.computeRefundForBurning(b + p, supply + mintingAmount, mintingAmount);
            assertApproxEqAbs(p, refundForMintAmount, 1 gwei, "p!=refundForMintAmount");
            uint256 priceForBurningAmount = quadraticCurve.computePriceForMinting(b, supply, burningAmount);
            assertApproxEqAbs(p, priceForBurningAmount, 1 gwei, "p!=priceForBurningAmount");
        }
    }

//    function test_linearCurveExpectedValues() public view {
//
//    }

}
