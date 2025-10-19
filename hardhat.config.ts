import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable } from "hardhat/config";

import hardhatVerify from "@nomicfoundation/hardhat-verify";


const config: HardhatUserConfig = {
  plugins: [hardhatToolboxMochaEthersPlugin,hardhatVerify],

  solidity: {
    profiles: {
      default: {
        version: "0.8.24",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
     npmFilesToBuild: [
      "@chainlink/contracts/src/v0.8/shared/token/ERC20/BurnMintERC20.sol",
      "@chainlink/contracts-ccip/contracts/pools/BurnMintTokenPool.sol",
      "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol",
      "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol"
     ]
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
      url: "",
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    hederaTestnet: {
      type: "http",
      chainType: "l1",
      url: "https://testnet.hashio.io/api",
      accounts: [""],
  },

},

verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    }
  }

}


export default config;
