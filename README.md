# Ztomic Swap – Smart Contracts

Official smart contracts repository for Ztomic Swap: a privacy-preserving, cross-chain atomic swap protocol built on incremental Merkle trees, zk verification, and Chainlink CCIP messaging/token transfers.

## Overview

Ztomic enables initiator/responder swaps with:

- Poseidon2-based incremental Merkle tree for commitments
- Nullifier protection to prevent double-spends
- Cross-chain root sharing via CCIP (LINK fee mode supported)
- Two zk verifiers (A/B) for proof validation
- Gas-optimized contract variant (`ZtomicOptimized`)

## Contracts

- `contracts/Ztomic.sol` — core swap contract; extends `IncrementalMerkleTree` and `CCIPTokenTransfererBytes`
- `contracts/ZtomicOptimized.sol` — optimized variant with same constructor interface
- `contracts/ccip/*` — CCIP helpers for token transfers and message passing
- `contracts/snarkVerifiers/*` — Honk-based verifiers (A and B)
- `contracts/IncrementalMerkleTree.sol` — Poseidon2 incremental tree

## Networks & Tooling

- Hardhat v3 (Ignition deployments)
- Networks in `hardhat.config.ts`:
  - `sepolia`, `hederaTestnet`, simulated: `hardhatMainnet`, `hardhatOp`
- Set config variables with `hardhat-keystore` or environment vars.

## Repository Structure

- `contracts/` — Solidity sources
- `ignition/modules/` — modular Ignition deployment modules
- `hardhat.config.ts` — multi-compiler profiles and networks
- `README.md` — this guide

## Usage

### Running Tests

To run all the tests in the project, execute the following command:

```shell
npx hardhat test
```

### Make a deployment to Sepolia

This project includes an example Ignition module to deploy the contract. You can deploy this module to a locally simulated chain or to Sepolia.

To run a local deployment, use any of the Ztomic modules, for example the full stack:

```shell
npx hardhat ignition deploy ignition/modules/deployStack.ts --network hardhatMainnet
```

To run the deployment to Sepolia, you need an account with funds to send the transaction. The provided Hardhat configuration includes a Configuration Variable called `SEPOLIA_PRIVATE_KEY`, which you can use to set the private key of the account you want to use.

You can set the `SEPOLIA_PRIVATE_KEY` variable using the `hardhat-keystore` plugin or by setting it as an environment variable.

To set the `SEPOLIA_PRIVATE_KEY` config variable using `hardhat-keystore`:

```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

After setting the variable, you can run the deployment with the Sepolia network:

```shell
npx hardhat ignition deploy --network sepolia ignition/modules/deployStack.ts --parameters ignition/parameters/stack.11155111.json
```

## Deployment Steps

### Deploying Ztomic Swap

To deploy the Ztomic Swap contract, you can use the `ignition/modules/ztomic.ts` module. This module takes several parameters:

- `depth`: The depth of the swap (default 20)
- `stableOne`: The address of the first stablecoin
- `stableTwo`: The address of the second stablecoin
- `ccipRouter`: The address of the CCIP router
- `linkToken`: The address of the link token
- `destinationChainSelector`: The destination chain selector (bigint)

You can pass these parameters via CLI flags or a JSON parameters file.

Example parameters file: `ignition/parameters/ztomic.sepolia.json`

```json
{
  "ZtomicModule": {
    "depth": 20,
    "stableOne": "0xStableOne...",
    "stableTwo": "0xStableTwo...",
    "ccipRouter": "0xRouter...",
    "linkToken": "0xLink...",
    "destinationChainSelector": "16015286601757825753"
  }
}
```

Command with parameters file:

```bash
npx hardhat ignition deploy ignition/modules/ztomic.ts --network sepolia --parameters ignition/parameters/ztomic.sepolia.json
```

### Deploying ZtomicOptimized

To deploy the ZtomicOptimized contract, you can use the `ignition/modules/ztomicOptimized.ts` module. This module takes the same parameters as the Ztomic module.

Example parameters file: `ignition/parameters/ztomicOptimized.sepolia.json`

```json
{
  "ZtomicOptimizedModule": {
    "depth": 20,
    "stableOne": "0xStableOne...",
    "stableTwo": "0xStableTwo...",
    "ccipRouter": "0xRouter...",
    "linkToken": "0xLink...",
    "destinationChainSelector": "16015286601757825753"
  }
}
```

Command:

```bash
npx hardhat ignition deploy ignition/modules/ztomicOptimized.ts --network sepolia --parameters ignition/parameters/ztomicOptimized.sepolia.json
```

### Deploying Full Stack

To deploy the full stack, you can use the `ignition/modules/deployStack.ts` module. This module takes the same parameters as the Ztomic module.

Example parameters file: `ignition/parameters/stack.sepolia.json`

```json
{
  "DeployZtomicStack": {
    "depth": 20,
    "stableOne": "0xStableOne...",
    "stableTwo": "0xStableTwo...",
    "ccipRouter": "0xRouter...",
    "linkToken": "0xLink...",
    "destinationChainSelector": "16015286601757825753"
  }
}
```

Command:

```bash
npx hardhat ignition deploy ignition/modules/deployStack.ts --network sepolia --parameters ignition/parameters/stack.sepolia.json
```

## Deployments (Ignition)

This repo uses Hardhat Ignition modules. You can pass parameters either via CLI flags or a JSON parameters file.

- Networks configured in `hardhat.config.ts`:
  - `sepolia`
  - `hederaTestnet`
  - local simulated: `hardhatMainnet`, `hardhatOp`

### Modules and commands

- Poseidon2 hasher
  - Module: `ignition/modules/poseidon.ts`
  - Command:
    ```bash
    npx hardhat ignition deploy ignition/modules/poseidon.ts --network sepolia
    ```

- Verifiers (A & B)
  - Module: `ignition/modules/verifiers.ts`
  - Command:
    ```bash
    npx hardhat ignition deploy ignition/modules/verifiers.ts --network sepolia
    ```

- Ztomic (classic)
  - Module: `ignition/modules/ztomic.ts`
  - Params:
    - `depth` (default 20)
    - `stableOne` (address)
    - `stableTwo` (address)
    - `ccipRouter` (address)
    - `linkToken` (address)
    - `destinationChainSelector` (bigint)
  - Example params file: `ignition/parameters/ztomic.sepolia.json`
    ```json
    {
      "ZtomicModule": {
        "depth": 20,
        "stableOne": "0xStableOne...",
        "stableTwo": "0xStableTwo...",
        "ccipRouter": "0xRouter...",
        "linkToken": "0xLink...",
        "destinationChainSelector": "16015286601757825753"
      }
    }
    ```
  - Command with params file:
    ```bash
    npx hardhat ignition deploy ignition/modules/ztomic.ts --network sepolia --parameters ignition/parameters/ztomic.sepolia.json
    ```

- ZtomicOptimized
  - Module: `ignition/modules/ztomicOptimized.ts`
  - Params: same as Ztomic
  - Example params file: `ignition/parameters/ztomicOptimized.sepolia.json`
    ```json
    {
      "ZtomicOptimizedModule": {
        "depth": 20,
        "stableOne": "0xStableOne...",
        "stableTwo": "0xStableTwo...",
        "ccipRouter": "0xRouter...",
        "linkToken": "0xLink...",
        "destinationChainSelector": "16015286601757825753"
      }
    }
    ```
  - Command:
    ```bash
    npx hardhat ignition deploy ignition/modules/ztomicOptimized.ts --network sepolia --parameters ignition/parameters/ztomicOptimized.sepolia.json
    ```

- Full stack (deploys both variants)
  - Module: `ignition/modules/deployStack.ts`
  - Example params file: `ignition/parameters/stack.sepolia.json`
    ```json
    {
      "DeployZtomicStack": {
        "depth": 20,
        "stableOne": "0xStableOne...",
        "stableTwo": "0xStableTwo...",
        "ccipRouter": "0xRouter...",
        "linkToken": "0xLink...",
        "destinationChainSelector": "16015286601757825753"
      }
    }
    ```
  - Command:
    ```bash
    npx hardhat ignition deploy ignition/modules/deployStack.ts --network sepolia --parameters ignition/parameters/stack.sepolia.json
    ```

- CCIP Token (Chainlink BurnMintERC20)
  - Module: `ignition/modules/CCIP_Deploy_Token.js`
  - Example params file: `ignition/parameters/ccip.token.sepolia.json`
    ```json
    {
      "CCIP_Deploy_Token": {
        "name": "Ztomic USDC",
        "symbol": "ZUSDC",
        "decimals": 6,
        "maxSupply": "1000000000000000",
        "preMint": "1000000000"
      }
    }
    ```
  - Command:
    ```bash
    npx hardhat ignition deploy ignition/modules/CCIP_Deploy_Token.js --network sepolia --parameters ignition/parameters/ccip.token.sepolia.json
    ```

- CCIP Pool (Chainlink BurnMintTokenPool)
  - Module: `ignition/modules/CCIP_Deploy_Pool.js`
  - Example params file: `ignition/parameters/ccip.pool.sepolia.json`
    ```json
    {
      "CCIP_Deploy_Pool": {
        "remoteToken": "0xRemoteToken...",
        "localTokenDecimals": 6,
        "rmnProxy": "0xRmnProxy...",
        "router": "0xRouter..."
      }
    }
    ```
  - Command:
    ```bash
    npx hardhat ignition deploy ignition/modules/CCIP_Deploy_Pool.js --network sepolia --parameters ignition/parameters/ccip.pool.sepolia.json
    ```

### Environment and config variables

Set RPC URLs and private keys using Hardhat Config Variables (recommended):

```bash
npx hardhat keystore set SEPOLIA_RPC_URL
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
npx hardhat keystore set ETHERSCAN_API_KEY
npx hardhat keystore set HEDERA_TESTNET_PRIVATE_KEY
```

Alternatively, define them as environment variables and reference them in `hardhat.config.ts`.

## Testing

### Solidity tests

- Run all tests:
  ```bash
  npx hardhat test
  ```
- Only Solidity tests:
  ```bash
  npx hardhat test solidity
  ```

### Mocha/TypeScript tests

- Only mocha tests:
  ```bash
  npx hardhat test mocha
  ```

### Local simulation

You can run Ignition against local simulated networks defined in `hardhat.config.ts`:

```bash
npx hardhat ignition deploy ignition/modules/deployStack.ts --network hardhatMainnet
```

### Verification

Etherscan verification is configured via `@nomicfoundation/hardhat-verify`:

```bash
npx hardhat verify --network sepolia <DEPLOYED_ADDRESS> <constructor-args-if-any>