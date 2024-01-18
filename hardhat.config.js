//require("@nomicfoundation/hardhat-toolbox");
//require("@nomicfoundation/hardhat-verify");
/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");

require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  allowUnlimitedContractSize: true,
  networks: {
    hardhat: {
      chainId: 555,
    },
    goerli_test: {
      url: process.env.GOERLITEST,
      accounts: [process.env.PRIVATE_KEY_TEST],
    },
    sepolia_test: {
      url: process.env.SEPOLIATEST,
      accounts: [process.env.PRIVATE_KEY_TEST],
    },
    bsc_test: {
      url: process.env.BSCTEST,
      accounts: [process.env.PRIVATE_KEY_TEST],
    },
    bsc_main: {
      url: process.env.BSCMAIN,
      accounts: [process.env.BSC_MAINNET_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.VERIFYAPI,
  },
};
