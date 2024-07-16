const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {
  const pump_fun = m.contract("PumpFun", ["0x6C4390E6c7b9668DC4BBf0049aC346622c9ACB0f", "0xc1A2116b647e9952FB743460EEFFc2B11a2bED33", "0x03640D168B2C5F35c9C7ef296f0F064a90E5FA62", 5]);

  return { pump_fun };
});