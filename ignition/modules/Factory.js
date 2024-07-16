const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {
  const factory = m.contract("Factory", ["0x03640D168B2C5F35c9C7ef296f0F064a90E5FA62"]);

  return { factory };
});