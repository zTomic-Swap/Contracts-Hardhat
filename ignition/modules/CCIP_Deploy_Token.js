import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("CCIP_Deploy_Token", (m) => {
  const NAME = m.getParameter("name", "Ztomic USDC");
  const SYMBOL = m.getParameter("symbol", "ZUSDC");
  const DECIMALS = m.getParameter("decimals", 6);
  const MAX_SUPPLY = m.getParameter("maxSupply", 1000000000000000n);
  const PRE_MINT = m.getParameter("preMint", 1000000000n);

  const deployCCIPToken = m.contract("BurnMintERC20", [
    NAME,
    SYMBOL,
    DECIMALS,
    MAX_SUPPLY,
    PRE_MINT,
  ]);

  return { deployCCIPToken };
})