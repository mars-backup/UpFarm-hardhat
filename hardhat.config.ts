import "@nomiclabs/hardhat-ethers"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-web3"
import "@nomiclabs/hardhat-etherscan"
import "@typechain/hardhat"
import "hardhat-gas-reporter"
import "solidity-coverage"
import "hardhat-deploy"
import "hardhat-spdx-license-identifier"

import { HardhatUserConfig } from "hardhat/config"
import dotenv from "dotenv"

dotenv.config()

const {
  CODE_COVERAGE,
  ETHERSCAN_API,
  ACCOUNT_PRIVATE_KEYS,
  FORK_MAINNET,
  BSC_MAINNET_API = "https://bsc-dataseed.binance.org/",
  BSC_TESTNET_API = "https://data-seed-prebsc-2-s2.binance.org:8545/"
} = process.env

let config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    mainnet: {
      url: BSC_MAINNET_API,
      gas: 6990000,
      gasPrice: 5000000000,
    },
    testnet: {
      url: BSC_TESTNET_API,
      gas: 6990000,
      gasPrice: 10000000000,
    },
  },
  paths: {
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000,
          },
        },
      }
    ],
  },
  typechain: {
    outDir: "./build/typechain/",
    target: "ethers-v5",
  },
  mocha: {
    timeout: 200000,
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      56: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
      97: 0,
    },
    libraryDeployer: {
      default: 1, // use a different account for deploying libraries on the hardhat network
      56: 0, // use the same address as the main deployer on mainnet
      97: 0,
    },
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
}

if (ETHERSCAN_API) {
  config = { ...config, etherscan: { apiKey: ETHERSCAN_API } }
}

if (ACCOUNT_PRIVATE_KEYS) {
  config.networks = {
    ...config.networks,
    mainnet: {
      ...config.networks?.mainnet,
      accounts: JSON.parse(ACCOUNT_PRIVATE_KEYS),
    },
    testnet: {
      ...config.networks?.testnet,
      accounts: JSON.parse(ACCOUNT_PRIVATE_KEYS),
    },
  }
}

if (FORK_MAINNET === "true" && config.networks) {
  console.log("FORK_MAINNET is set to true")
  config = {
    ...config,
    networks: {
      ...config.networks,
      hardhat: {
        ...config.networks.hardhat,
        forking: {
          url: BSC_MAINNET_API || "",
        },
        chainId: 56,
      },
    },
    external: {
      deployments: {
        hardhat: ["deployments/mainnet"],
      },
    },
  }
}

export default config
