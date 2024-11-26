pragma solidity >=0.8.26;

import "forge-std/Script.sol";
import {UD60x18, ud, convert, pow} from "@prb/math/src/UD60x18.sol";

contract PrbPowerEnumeration is Script {
    function run() public {
//        uint256 FROM = 1000; // good
//        uint256 FROM = 1000000; // good
        uint256 FROM = 1000000000; // still good!
        for (uint256 i = FROM; i < FROM * 10; i += FROM) {

            UD60x18 aw = pow(ud(i * 1e18), ud(2e18));
            uint256 a = convert(aw);
            uint256 b = i * i;
            int256 diff = int256(a) - int256(b);
            int256 diffp = (diff * 1 ether) / int256(b);
            console.log("a = %s | b = %s", a, b);
            console.log("| diff = %s", diff);
            console.log("| diff% = %e", diffp);
        }
    }
}