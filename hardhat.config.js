require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");

const {
  PRIVATE__KEY,
  PRIVATE_KEY,
  SEPOLIA_API_URL,
  MAINNET_API_URL,
  ETHERSCAN_API_KEY,
  BASE_API_KEY
} = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {},
    sepolia: {
      url: `${SEPOLIA_API_URL}`,
      accounts: [`0x${PRIVATE__KEY}`]
    },
    mainnet: {
      url: `${MAINNET_API_URL}`,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    base_mainnet: {
      url: 'https://mainnet.base.org',
      accounts: [`0x${PRIVATE_KEY}`],
      gasPrice: 1000000000,
    },
    base_sepolia: {
      url: 'https://sepolia.base.org',
      accounts: [`0x${PRIVATE__KEY}`],
      gasPrice: 1000000000,
    }
  },
  paths: {
    sources: "./contracts",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  },
  etherscan: {
    apiKey: BASE_API_KEY
  },
  sourcify: {
    enabled: true
  }
};
