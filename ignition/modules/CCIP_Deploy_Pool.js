import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TokenAddress_hedera = "0x6E08a948F54f82aC8B3484348B80D2dA2E9e20c1";
const TokenAddress_sepolia = "0x50EE5f5E0DECFf705682DF6a418805b48da32A2a";
const localTokenDecimals = 6;
const rmnProxy_hedera = "0x0Df355104424BABfb2404600A4258CfE140a78Cf";
const rmnProxy_sepolia = "0xba3f6251de62dED61Ff98590cB2fDf6871FbB991";
const router_hedera = "0x802C5F84eAD128Ff36fD6a3f8a418e339f467Ce4";
const router_sepolia = "0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59";
const NAME = "Ztomic USDC"


export default buildModule("CCIP_Deploy_Pool", (m) => {

const token = m.contractAt("BurnMintERC20", TokenAddress_sepolia);

 const deployCCIPToken = m.contract("BurnMintTokenPool", [
    TokenAddress_hedera,
    localTokenDecimals,
    [],
    rmnProxy_hedera,
    router_hedera,
  ]);

  return { deployCCIPToken };

})