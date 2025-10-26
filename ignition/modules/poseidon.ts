import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploy Poseidon2 hasher from poseidon2-evm package
export default buildModule("Poseidon2Module", (m) => {
  const poseidon2 = m.contract("poseidon2-evm/src/Poseidon2.sol:Poseidon2");
  return { poseidon2 };
});
