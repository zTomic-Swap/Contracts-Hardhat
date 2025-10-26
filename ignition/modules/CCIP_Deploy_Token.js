import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

    const NAME = "Ztomic USDC"
    const SYMBOL = "ZUSDC"
   const DECIMALS = 6
   const MAX_SUPPLY = 1000000000000000
   const PRE_MINT = 1000000000
   const VERIFY_CONTRACT = true


export default buildModule("CCIP_Deploy_Token", (m) => {

 const deployCCIPToken = m.contract("BurnMintERC20", [
    NAME,
    SYMBOL,
    DECIMALS,
    MAX_SUPPLY,
    PRE_MINT,
  ]);

  return { deployCCIPToken };

})