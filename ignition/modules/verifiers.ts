import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("VerifiersModule", (m) => {
  const verifierA = m.contract(
    "contracts/snarkVerifiers/aContract/aliceVerifier.sol:HonkVerifier"
  );
  const verifierB = m.contract(
    "contracts/snarkVerifiers/bContract/bobVerifier.sol:HonkVerifier"
  );
  return { verifierA, verifierB };
});
