// generateBobCommitment.ts
import { Barretenberg, Fr } from "@aztec/bb.js";
import { Base8, mulPointEscalar } from "@zk-kit/baby-jubjub";
import { ethers } from "ethers";
import { fileURLToPath } from "url";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

import fs from "fs";
import path from "path";

const circuit = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, "../../Circuits-Noir/target/circuit_bob.json"),
    "utf8"
  )
);

export function derivePublicKey(privateKeyHex: string) {
  const privateKey = BigInt(privateKeyHex);
  const publicKey = mulPointEscalar(Base8, privateKey);
  return {
    x: `0x${publicKey[0].toString(16)}`,
    y: `0x${publicKey[1].toString(16)}`,
  };
}
export default async function generateBobCommitment(): Promise<string> {
  const bb = await Barretenberg.new();

  const aliceKey = "0x12345";
  const bobKey = "0x67890";

  const inputs = process.argv.slice(2);

  const reconstructed_hash_lock = Fr.fromString(inputs[0]); //hash_lock

  const alicePk = derivePublicKey(aliceKey);
  const bob_sk = BigInt(bobKey);

  const alice_pk_point: [bigint, bigint] = [
    BigInt(alicePk.x),
    BigInt(alicePk.y),
  ];

  try {
    const shared_secret = mulPointEscalar(alice_pk_point, bob_sk);
    const shared_secret_x = shared_secret[0];

    const shared_secret_x_fr = new Fr(shared_secret_x);

    const derived_commitment_fr = await bb.poseidon2Hash([
      reconstructed_hash_lock,
      shared_secret_x_fr,
    ]);

    const result = ethers.AbiCoder.defaultAbiCoder().encode(
      ["bytes32"],
      [derived_commitment_fr.toBuffer()]
    );

    return result;
  } catch (error) {
    console.error("generateBobCommitment error:", error);
    throw error;
  } finally {
    await bb.destroy();
  }
}

(async () => {
  generateBobCommitment()
    .then((result) => {
      process.stdout.write(result);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
})();
