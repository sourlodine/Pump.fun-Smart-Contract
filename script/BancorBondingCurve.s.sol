pragma solidity >=0.8.26;

import "forge-std/Script.sol";
import "@contracts/BancorBondingCurve.sol";

contract BancorBondingCurveDetail is Script {
    BancorBondingCurve internal curve;
    //    uint256 internal SLOPE = vm.envUint("SLOPE");
    uint256 internal SLOPE_SCALED = vm.envOr("SLOPE_SCALED", uint256(0));
    //    uint32 internal N = uint32(vm.envUint("N"));
    uint32 internal WEIGHT_SCALED = uint32(vm.envOr("WEIGHT_SCALED", uint256(0)));

    function run() public {
        curve = new BancorBondingCurve(SLOPE_SCALED, WEIGHT_SCALED);
        //        curve = new BancorBondingCurve(SLOPE * SLOPE_SCALE, MAX_WEIGHT / (1 + N));
//        mintingByAmountIncremental();
        mintingByPriceIncremental();
    }

    function mintingByPriceIncremental() public {
        uint256 numIncrements = vm.envUint("NUM_INCREMENTS");
        uint256 b = 0;
        uint256 supply = 0;
        uint256 totalPrice = vm.envUint("PRICE");
        uint256 perIncrementPrice = totalPrice / numIncrements;
        for (uint256 i = 0; i < numIncrements; i++) {
            uint256 k = curve.computeMintingAmountFromPrice(b, supply, perIncrementPrice);
            console.log("b = %s | supply = %s | p = %s", b, supply, k);
            supply += k;
            b += perIncrementPrice;
        }
        console.log("b = %s supply = %s", b, supply);
        //        p = ((totalMintAmount ** (N + 1)) * SLOPE_SCALED) / (N + 1) / SLOPE_SCALE;
        // totalMintAmount = log(p * SLOPE_SCALE * (N+1) / SLOPE_SCALED) / (N+1)

        uint256 estimated = ((supply ** (1 + 3)) * SLOPE_SCALED) / (1 + 3) / SLOPE_SCALE;

//        uint256 result;
//        uint256 precision;
//        (result, precision) = power(supply , 1, MAX_WEIGHT, WEIGHT_SCALED);
//        uint256 estimated = ((result * SLOPE_SCALED * WEIGHT_SCALED) / MAX_WEIGHT / SLOPE_SCALE) >> precision;

        console.log("diff = %s", int256(estimated) - int256(b));
//        console.log("| precision = %s", int256(precision));
//        console.log("| result = %s", int256(result));
        console.log("diff% = %e", ((int256(estimated) - int256(b)) * 1 ether) / int256(estimated));

    }

    function mintingByAmountIncremental() public {
        uint256 numIncrements = vm.envUint("NUM_INCREMENTS");
        uint256 b = 0;
        uint256 supply = 0;
        uint256 totalMintAmount = vm.envUint("MINT_AMOUNT");
        uint256 perIncrementMintAmount = totalMintAmount / numIncrements;
        uint256 pPrev = 0;
        for (uint256 i = 0; i < numIncrements; i++) {
            uint256 p = curve.computePriceForMinting(b, supply, perIncrementMintAmount);
            console.log("b = %s | supply = %s | p = %s", b, supply, p);
            console.log("| p_delta = %s", p - pPrev);
            pPrev = p;
            b += p;
            supply += perIncrementMintAmount;
        }
        console.log("b = %s supply = %s", b, supply);

        //        uint256 estimated = ((totalMintAmount ** (N + 1)) * SLOPE) / (N + 1);
//        uint256 result;
//        uint256 precision;
//        (result, precision) = power(totalMintAmount, 1, MAX_WEIGHT, WEIGHT_SCALED);
//        uint256 estimated = ((result * SLOPE_SCALED * WEIGHT_SCALED) / MAX_WEIGHT / SLOPE_SCALE) >> precision;

        uint256 estimated = ((totalMintAmount ** (1 + 1)) * SLOPE_SCALED) / (1 + 1) / SLOPE_SCALE;

        console.log("estimated = %s", int256(estimated));
        //        console.log("| precision = %s", int256(precision));
        //        console.log("| result = %s", int256(result));
        console.log("diff = %s", int256(estimated) - int256(b));
        console.log("diff% = %e", ((int256(estimated) - int256(b)) * 1 ether) / int256(estimated));
    }
}
