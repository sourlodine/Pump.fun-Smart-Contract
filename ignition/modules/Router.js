const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {
  const router = m.contract("Router", ["0x6C4390E6c7b9668DC4BBf0049aC346622c9ACB0f", "0x4200000000000000000000000000000000000006", 1]);

  return { router };
});