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

const circuit = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, "../../Circuits-Noir/target/circuit_alice.json"),
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
export default async function generateAliceProof() {
  // Initialize Barretenberg
  const bb = await Barretenberg.new();

  const aliceKey = "0x12345";
  const bobSk = "0x67890";
  const bobPk = derivePublicKey(bobSk);
  const alice_sk = BigInt(aliceKey);
  const bob_pk_point: [bigint, bigint] = [BigInt(bobPk.x), BigInt(bobPk.y)];

  // Get the commitment leaves, nullifier and secret from process args
  const inputs = process.argv.slice(2);

  const order_id = inputs[0];
  const nonce_str = inputs[1];

  const leaves = inputs.slice(2);

  const tree = await merkleTree(leaves);

  // Create the commitment

  const shared_secret = mulPointEscalar(bob_pk_point, alice_sk);
  const shared_secret_x = shared_secret[0];

  const bob_pk_x_fr = new Fr(bob_pk_point[0]);
  const nonce_fr = new Fr(BigInt(nonce_str));
  const order_id_fr = new Fr(BigInt(order_id));

  const reconstructed_hash_lock_fr = await bb.poseidon2Hash([
    bob_pk_x_fr,
    nonce_fr,
  ]);

  const shared_secret_x_fr = new Fr(shared_secret_x);

  const computed_nullifier_fr = await bb.poseidon2Hash([
    shared_secret_x_fr,
    bob_pk_x_fr,
    order_id_fr,
  ]);

  const derived_commitment_fr = await bb.poseidon2Hash([
    reconstructed_hash_lock_fr,
    shared_secret_x_fr,
  ]);

  const merkleProof = tree.proof(
    tree.getIndex(derived_commitment_fr.toString())
  );
  try {
    const noir = new Noir(circuit);
    const honk = new UltraHonkBackend(circuit.bytecode, { threads: 1 });

    const input = {
      alice_priv_key: aliceKey,
      bob_pub_key_x: bobPk.x,
      bob_pub_key_y: bobPk.y,
      order_id: order_id.toString(),
      merkle_proof: merkleProof.pathElements.map((s) => s.toString()),
      is_even: merkleProof.pathIndices.map((i) => i % 2 == 0),
      hash_lock_nonce: nonce_str.toString(),
      nullifier_hash: computed_nullifier_fr.toString(),
      root: merkleProof.root.toString(),
    };

    const { witness } = await noir.execute(input);

    const originalLog = console.log; // Save original
    // Override to silence all logs
    console.log = () => {};

    const { proof, publicInputs } = await honk.generateProof(witness, {
      keccak: true,
    });
    // Restore original console.log
    console.log = originalLog;

    // const isValid = await honk.verifyProof({ proof, publicInputs });

    const result = ethers.AbiCoder.defaultAbiCoder().encode(
      ["bytes", "bytes32[]"],
      [proof, publicInputs]
    );
    return result;
  } catch (error) {
    console.log(error);
    throw error;
  } finally {
    await bb.destroy();
  }
}

(async () => {
  generateAliceProof()
    .then((result) => {
      process.stdout.write(result);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
})();
