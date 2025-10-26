cmd:
yarn hardhat test solidity

npx tsx js-scripts/genAliceComittment_StandAlone.js

ECDH is symmetric

shared_A = mulPointEscalar(bob_pk, alice_sk) = (G _ bob_sk) _ alice_sk = G _ (alice_sk _ bob_sk)
shared_B = mulPointEscalar(alice_pk, bob_sk) = (G _ alice_sk) _ bob_sk = G _ (alice_sk _ bob_sk)

so have maintained two seperate commitments variables

npm install "poseidon2-evm"
npm config set loglevel=error

https://getfoundry.sh/config/hardhat/

npm install --save-dev "hardhat@^3.0.7" "@nomicfoundation/hardhat-toolbox-mocha-ethers@^3.0.0" "@nomicfoundation/hardhat-ignition@^3.0.0" "@types/chai@^4.2.0" "@types/chai-as-promised@^8.0.1" "@types/mocha@>=10.0.10" "@types/node@^22.8.5" "chai@^5.1.2" "ethers@^6.14.0" "forge-std@foundry-rs/forge-std#v1.9.4" "mocha@^11.0.0" "typescript@~5.8.0"
npm i --save-dev @nomicfoundation/hardhat-foundry

https://github.com/yashsharma22003/ztomic-foundry

https://github.com/zTomic-Swap/Contracts-Hardhat
npm install @openzeppelin/contracts @chainlink/contracts @chainlink/contracts-ccip poseidon2-evm
updated @poseidon2/src/ to poseidon2-evm/src in contracts

import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

const pubKeyString = '0x049063c5815255596f680d1f94a4258e20eaa470a7e7557f01bd6cdcfcd44239168acb9f6f24fcd3a05f9f6aec43f6e2042de2b97fe5aa6a758f6962ac6271bf31';
const coordsString = pubKeyString.slice(4, pubKeyString.length); // removes 0x04
const x = BigInt('0x' + coordsString.slice(0, 64)); // x is the first half
const y = BigInt('0x' + coordsString.slice(64, coordsString.length)); // y is the second half

0x0x1d124fda5164b19e39d07624ea49846f509c91535e70629db7da1802bb75795ccfade8b7c31f21482f29de9bea6107082bbac64bf9e0a74e560fd3d4244730e

https://github.com/zk-kit/zk-kit/tree/main/packages/baby-jubjub
import { packPoint, unpackPoint, Base8, mulPointEscalar, Point, addPoint } from "@zk-kit/baby-jubjub"

// Define two points on the BabyJubJub curve.
const p1: Point<bigint> = [BigInt(0), BigInt(1)] // Point at infinity (neutral element).
const p2: Point<bigint> = [BigInt(1), BigInt(0)] // Example point.

// Add the two points on the curve.
const p3 = addPoint(p1, p2)

// Add the result with Base8, another point on the curve, to get a new point.
const secretScalar = addPoint(Base8, p3)

// Multiply the base point by the x-coordinate of the secret scalar to get the public key.
const publicKey = mulPointEscalar(Base8, secretScalar[0])

// Pack the public key into a compressed format.
const packedPoint = packPoint(publicKey)

// Unpack the compressed public key back into its original form.
const unpackedPoint = unpackPoint(packedPoint)

if (unpackedPoint) {
console.log(publicKey[0] === unpackedPoint[0]) // true, checks if x-coordinates match
console.log(publicKey[1] === unpackedPoint[1]) // true, checks if y-coordinates match
}
https://github.com/zk-kit/zk-kit/tree/main/packages/eddsa-poseidon
