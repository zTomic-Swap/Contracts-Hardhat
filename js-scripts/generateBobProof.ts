// generateBobProof.ts
import { Barretenberg, Fr, UltraHonkBackend } from "@aztec/bb.js";
import { ethers } from "ethers";
import { merkleTree } from "./merkleTree.js";
import { Noir } from "@noir-lang/noir_js";
import { Base8, mulPointEscalar } from "@zk-kit/baby-jubjub";
import { fileURLToPath } from "url";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

import path from "path";
import fs from "fs";

// NOTE: adjust filename if your bob circuit json differs
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

export default async function generateBobProof() {
  const bb = await Barretenberg.new();
  const aliceKey = "0x12345";
  const bobKey = "0x67890";

  const inputs = process.argv.slice(2);

  const order_id_fr = Fr.fromString(inputs[0]);
  const hash_lock_nonce_fr = Fr.fromString(inputs[1]);
  const leaves = inputs.slice(2); // remaining args are merkle leaves

  const alicePk = derivePublicKey(aliceKey);
  const bob_sk = BigInt(bobKey);

  const alice_pk_point: [bigint, bigint] = [
    BigInt(alicePk.x),
    BigInt(alicePk.y),
  ];

  const tree = await merkleTree(leaves);

  try {
    const bobPk = derivePublicKey(bobKey);
    const bob_pk_point: [bigint, bigint] = [BigInt(bobPk.x), BigInt(bobPk.y)];

    // Shared secret: bob_sk * alice_pub_key
    const shared_secret = mulPointEscalar(alice_pk_point, bob_sk);
    const shared_secret_x = shared_secret[0];

    // Build Fr objects
    const bob_pk_x_fr = new Fr(bob_pk_point[0]);
    const shared_secret_x_fr = new Fr(shared_secret_x);

    // reconstructed_hash_lock = Poseidon2::hash([bob_pk.x, hash_lock_nonce], 2)
    const reconstructed_hash_lock_fr = await bb.poseidon2Hash([
      bob_pk_x_fr,
      hash_lock_nonce_fr,
    ]);

    // computed_nullifier_hash = Poseidon2::hash([shared_secret, alice_pub_key_x, order_id], 3)
    const alice_pk_x_fr = new Fr(alice_pk_point[0]);
    const computed_nullifier_fr = await bb.poseidon2Hash([
      shared_secret_x_fr,
      alice_pk_x_fr,
      order_id_fr,
    ]);

    const derived_commitment_fr = await bb.poseidon2Hash([
      reconstructed_hash_lock_fr,
      shared_secret_x_fr,
    ]);

    const merkleProof = tree.proof(
      tree.getIndex(derived_commitment_fr.toString())
    );

    const noir = new Noir(circuit);
    const honk = new UltraHonkBackend(circuit.bytecode, { threads: 1 });

    const input = {
      bob_priv_key: bobKey,
      alice_pub_key_x: alicePk.x,
      alice_pub_key_y: alicePk.y,
      hash_lock_nonce: hash_lock_nonce_fr.toString(),
      order_id: order_id_fr.toString(),
      merkle_proof: merkleProof.pathElements.map((s) => s.toString()),
      is_even: merkleProof.pathIndices.map((i: number) => i % 2 == 0),
      nullifier_hash: computed_nullifier_fr.toString(),
      root: merkleProof.root.toString(),
    };

    const { witness } = await noir.execute(input);

    const originalLog = console.log;
    console.log = () => {};

    const { proof, publicInputs } = await honk.generateProof(witness, {
      keccak: true,
    });

    console.log = originalLog;

    const result = ethers.AbiCoder.defaultAbiCoder().encode(
      ["bytes", "bytes32[]"],
      [proof, publicInputs]
    );

    return result;
  } catch (error) {
    console.error("generateBobProof error:", error);
    throw error;
  } finally {
    await bb.destroy();
  }
}

(async () => {
  generateBobProof()
    .then((result) => {
      process.stdout.write(result);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
})();
