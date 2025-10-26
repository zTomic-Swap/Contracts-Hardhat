import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import Poseidon2Module from "./poseidon.js";
import VerifiersModule from "./verifiers.js";

export default buildModule("ZtomicOptimizedModule", (m) => {
  // Parameters
  const depth = m.getParameter("depth", 20);
  const stableOne = m.getParameter<string>("stableOne");
  const stableTwo = m.getParameter<string>("stableTwo");
  const ccipRouter = m.getParameter<string>("ccipRouter");
  const linkToken = m.getParameter<string>("linkToken");
  const destinationChainSelector = m.getParameter<bigint>(
    "destinationChainSelector"
  );

  // Dependencies
  const { poseidon2 } = m.useModule(Poseidon2Module);
  const { verifierA, verifierB } = m.useModule(VerifiersModule);

  const ztomicOptimized = m.contract("ZtomicOptimized", [
    depth,
    poseidon2,
    stableOne,
    stableTwo,
    ccipRouter,
    linkToken,
    destinationChainSelector,
    verifierA,
    verifierB,
  ]);

  return { ztomicOptimized };
});
