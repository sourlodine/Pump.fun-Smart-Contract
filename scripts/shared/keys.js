const { hashString, hashData } = require("./hash")

const CLAIMABLE_FEE_AMOUNT = hashString("CLAIMABLE_FEE_AMOUNT")

function claimableFeeAmountKey(market, token) {
  return hashData(["bytes32", "address", "address"], [CLAIMABLE_FEE_AMOUNT, market, token]);
}

module.exports = {
  claimableFeeAmountKey
}
