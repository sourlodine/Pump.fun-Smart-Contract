function encodeData(dataTypes, dataValues) {
  const bytes = ethers.utils.defaultAbiCoder.encode(dataTypes, dataValues);
  return ethers.utils.hexlify(bytes);
}

function hashData(dataTypes, dataValues) {
  const bytes = ethers.utils.defaultAbiCoder.encode(dataTypes, dataValues);
  const hash = ethers.utils.keccak256(ethers.utils.arrayify(bytes));

  return hash;
}

function hashString(string) {
  return hashData(["string"], [string]);
}

module.exports = {
  hashData,
  hashString
}
