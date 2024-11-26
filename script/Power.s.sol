pragma solidity >=0.8.26;

import "forge-std/Script.sol";
import "@contracts/Power.sol";

contract PowerEnumeration is Script, Power {
//    uint256 internal POWER = vm.envOr("POWER", uint256(0));
    function run() public {
        uint256 FROM = 1000; // still works
//        uint256 FROM = 1000000; // This is where it starts to break down!
//        uint256 FROM = 1000000000; // Diff totally goes off!
        for (uint256 i = FROM; i < FROM * 10; i += FROM) {
            (uint256 r, uint256 p) = power(i, 1, 2, 1);
            uint256 a = r >> p;
            uint256 b = i * i;
            int256 diff = int256(a) - int256(b);
            int256 diffp = (diff * 1 ether) / int256(b);
            console.log("a = %s | b = %s", a, b);
            console.log("| diff = %s", diff);
            console.log("| diff% = %e", diffp);
        }
    }
}