import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("CCIP_Deploy_Pool", (m) => {
  const remoteToken = m.getParameter("remoteToken");
  const localTokenDecimals = m.getParameter("localTokenDecimals", 6);
  const rmnProxy = m.getParameter("rmnProxy");
  const router = m.getParameter("router");

  // Optional: attach to an already deployed ERC20 if needed
  // const token = m.contractAt("BurnMintERC20", m.getParameter("localToken"));

  const pool = m.contract("BurnMintTokenPool", [
    remoteToken,
    localTokenDecimals,
    [],
    rmnProxy,
    router,
  ]);

  return { pool };
})