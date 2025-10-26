import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable } from "hardhat/config";

import hardhatVerify from "@nomicfoundation/hardhat-verify";

// import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxMochaEthersPlugin, hardhatVerify],
  test: {
    solidity: {
      ffi: true, // Enable FFI for Solidity tests
    },
  },
  solidity: {
    profiles: {
      default: {
        compilers: [
          { version: "0.8.24" }, // your contracts
          { version: "0.8.20" }, // Chainlink 1.4.x / 1.5.x
          { version: "0.8.30" },
        ],
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
    },
    npmFilesToBuild: [
      "@chainlink/contracts/src/v0.8/shared/token/ERC20/BurnMintERC20.sol",
      "@chainlink/contracts-ccip/contracts/pools/BurnMintTokenPool.sol",
      "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol",
      "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol",
    ],
  },

  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    hederaTestnet: {
      type: "http",
      chainType: "l1",
      url: "https://testnet.hashio.io/api",
      accounts: [configVariable("HEDERA_TESTNET_PRIVATE_KEY")],
    },
  },

  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
  },
};

export default config;
