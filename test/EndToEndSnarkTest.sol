// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ZtomicOptimized} from "../contracts/ZtomicOptimized.sol";
import {Poseidon2} from "poseidon2-evm/src/Poseidon2.sol";
import {ERC20Mock} from "./utils/ERC20Mock.sol";
import {IVerifier} from "../contracts/interface/IVerifier.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper, WETH9} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

import {HonkVerifier as VerifierA} from "../contracts/snarkVerifiers/aContract/aliceVerifier.sol";
import {HonkVerifier as VerifierB} from "../contracts/snarkVerifiers/bContract/bobVerifier.sol";

contract ZtomicTest is Test {
    ZtomicOptimized public ztomic;
    ERC20Mock public stableOne;
    ERC20Mock public stableTwo;
    Poseidon2 public hasher;
    VerifierA public verifierA;
    VerifierB public verifierB;
    CCIPLocalSimulator public ccipLocalSimulator;
    IVerifier public aliceVerifier;
    IVerifier public bobVerifier;

    uint256 internal constant SNARK_FIELD_PRIME =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 alicePrivKey = 0x12345; // or any uint256
    uint256 bobPrivKey = 0x67890; // or any uint256

    // Derive Ethereum address from private key

    address public alice = vm.addr(alicePrivKey);
    address public bob = vm.addr(bobPrivKey);

    uint256 constant SWAP_DENOMINATION = 1e6;

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();

        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            WETH9 wrappedNative,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,
            BurnMintERC677Helper ccipLnM
        ) = ccipLocalSimulator.configuration();

        stableOne = new ERC20Mock("StableOne", "ST1");
        stableTwo = new ERC20Mock("StableTwo", "ST2");
        hasher = new Poseidon2();
        verifierA = new VerifierA();
        verifierB = new VerifierB();

        ztomic = new ZtomicOptimized(
            20,
            hasher,
            address(stableOne),
            address(stableTwo),
            address(sourceRouter),
            address(linkToken),
            chainSelector,
            address(verifierA),
            address(verifierB)
        );

        stableOne.mint(alice, SWAP_DENOMINATION * 10);
        stableTwo.mint(bob, SWAP_DENOMINATION * 10);
    }

    function toField(bytes32 b) internal pure returns (bytes32) {
        return bytes32(uint256(b) % SNARK_FIELD_PRIME);
    }
    function bytes32ToString(
        bytes32 _bytes32
    ) public pure returns (string memory) {
        return string(abi.encodePacked(_bytes32));
    }
    function _getAliceProof(
        bytes32 hash_lock_nonce,
        bytes32 order_id,
        bytes32[] memory leaves
    ) internal returns (bytes memory proof, bytes32[] memory publicInputs) {
        string[] memory inputs = new string[](5 + leaves.length);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateAliceProof.ts";
        inputs[3] = vm.toString(order_id);
        inputs[4] = vm.toString(hash_lock_nonce);
        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[5 + i] = vm.toString(leaves[i]);
        }
        bytes memory result = vm.ffi(inputs);
        (proof, publicInputs) = abi.decode(result, (bytes, bytes32[]));
    }

    function _getAliceCommitment()
        internal
        returns (
            bytes32 commitment,
            bytes32 hash_lock_nonce,
            bytes32 hash_lock,
            bytes32 order_id,
            bytes32 nullifier
        )
    {
        string[] memory inputs = new string[](3);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateAliceCommitment.ts";

        bytes memory result = vm.ffi(inputs);

        bytes32[5] memory out = abi.decode(result, (bytes32[5]));

        commitment = out[0];
        hash_lock_nonce = out[1];
        hash_lock = out[2];
        order_id = out[3];
        nullifier = out[4];
    }
    function testGenerateProofsAndVerify() public {
        //ALICE PROOF
        (
            bytes32 commitmentA,
            bytes32 hash_lock_nonce,
            bytes32 hash_lock,
            bytes32 order_id,
            bytes32 nullifierA
        ) = _getAliceCommitment();

        assertTrue(commitmentA != 0);
        assertTrue(hash_lock_nonce != 0);
        assertTrue(hash_lock != 0);

        assertTrue(order_id != 0);
        assertTrue(nullifierA != 0);

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = commitmentA;

        (bytes memory proofA, bytes32[] memory publicInputsA) = _getAliceProof(
            hash_lock_nonce,
            order_id,
            leaves
        );
        //@audit-issue - sorry i was not able to do this verify part, please make it work - custom error ed74ac0a:
        assertTrue(verifierA.verify(proofA, publicInputsA));
        //BOB PROOF
        bytes32 commitmentB = _getBobCommitment(hash_lock);
        assertTrue(commitmentB != 0);

        bytes32[] memory leavesB = new bytes32[](1);
        leavesB[0] = commitmentB;

        // Fetch proof by invoking the TS script with VM FFI
        (bytes memory proofB, bytes32[] memory publicInputsB) = _getBobProof(
            order_id,
            hash_lock_nonce,
            leavesB
        );
        // Sanity checks on returned values
        assertTrue(proofB.length > 0);
        assertTrue(publicInputsB.length > 0);
        //@audit-issue - same here. proofs generation working properly but verification not working even through cli for me
        assertTrue(verifierB.verify(proofB, publicInputsB));
    }

    function _getBobProof(
        bytes32 order_id,
        bytes32 hash_lock_nonce,
        bytes32[] memory leaves
    ) internal returns (bytes memory proof, bytes32[] memory publicInputs) {
        string[] memory inputs = new string[](5 + leaves.length);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateBobProof.ts";
        inputs[3] = vm.toString(order_id);
        inputs[4] = vm.toString(hash_lock_nonce);

        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[5 + i] = vm.toString(leaves[i]);
        }

        bytes memory result = vm.ffi(inputs);
        (proof, publicInputs) = abi.decode(result, (bytes, bytes32[]));
    }

    /// @dev Call the Node/TS script that computes Bob's commitment bundle:
    /// returns (derived_commitment, hash_lock_nonce, order_id, nullifier)
    function _getBobCommitment(
        bytes32 hash_lock
    ) internal returns (bytes32 commitment) {
        string[] memory inputs = new string[](4);

        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateBobCommitment.ts";
        inputs[3] = vm.toString(hash_lock);

        bytes memory result = vm.ffi(inputs);

        bytes32[1] memory out = abi.decode(result, (bytes32[1]));

        commitment = out[0];
    }

    struct AliceData {
        bytes32 commitment;
        bytes32 hash_lock_nonce;
        bytes32 hash_lock;
        bytes32 order_id;
        bytes32 nullifier;
    }

    function testEndToEndAtomicSwap() public {
        AliceData memory aliceData;
        (
            aliceData.commitment,
            aliceData.hash_lock_nonce,
            aliceData.hash_lock, // posHash( bob pub + hash_lock_nonce )
            aliceData.order_id,
            aliceData.nullifier
        ) = _getAliceCommitment();

        // === Step 1: Alice deposits stableOne (initiator) ===
        vm.startPrank(alice);
        stableOne.approve(address(ztomic), SWAP_DENOMINATION);

        // bytes32 commitment = bytes32(uint256(hash) % fieldSize);

        ztomic.deposit_initiator(
            aliceData.commitment,
            aliceData.order_id,
            aliceData.hash_lock,
            false,
            address(0)
        );
        vm.stopPrank();

        assertEq(stableOne.balanceOf(alice), SWAP_DENOMINATION * 9);
        assertEq(stableOne.balanceOf(address(ztomic)), SWAP_DENOMINATION);
        assertEq(stableTwo.balanceOf(address(ztomic)), 0); // nothing yet

        // === Step 2: Bob deposits stableTwo (responder) ===
        vm.startPrank(bob);

        stableTwo.approve(address(ztomic), SWAP_DENOMINATION);
        bytes32 commitmentB = _getBobCommitment(aliceData.hash_lock);
        ztomic.deposit_responder(commitmentB, false, address(0));

        vm.stopPrank();

        assertEq(stableTwo.balanceOf(bob), SWAP_DENOMINATION * 9);
        assertEq(stableTwo.balanceOf(address(ztomic)), SWAP_DENOMINATION);
        assertEq(stableOne.balanceOf(address(ztomic)), SWAP_DENOMINATION); // both tokens now in

        // === Step 3: Alice withdraws stableTwo (as initiator completing swap) ===

        bytes32[] memory leavesA = new bytes32[](1);
        leavesA[0] = aliceData.commitment;
        // create a proof
        (bytes memory proofA, bytes32[] memory publicInputsA) = _getAliceProof(
            aliceData.hash_lock_nonce,
            aliceData.order_id,
            leavesA
        );
        assertTrue(verifierA.verify(proofA, publicInputsA));

        ztomic.withdraw_initiator(
            proofA,
            publicInputsA[1],
            publicInputsA[2],
            publicInputsA[0],
            aliceData.order_id,
            alice // Alice receives stableTwo
        );

        vm.stopPrank();

        assertEq(stableTwo.balanceOf(alice), SWAP_DENOMINATION); // Alice got stableTwo
        assertEq(stableTwo.balanceOf(address(ztomic)), 0);

        // === Step 4: Bob withdraws stableOne (as responder completing swap) ===
        // root = ztomic.getLatestRoot(); // root may have changed after Alice's withdraw

        bytes32[] memory leavesB = new bytes32[](1);
        leavesB[0] = commitmentB;

        (bytes memory proofB, bytes32[] memory publicInputsB) = _getBobProof(
            aliceData.order_id,
            aliceData.hash_lock_nonce,
            leavesB
        );
        assertTrue(verifierB.verify(proofB, publicInputsB));

        ztomic.withdraw_responder(
            proofB,
            publicInputsB[0], //nullifier
            publicInputsB[1], //root
            bob // Bob receives stableOne
        );

        vm.stopPrank();

        assertEq(stableOne.balanceOf(bob), SWAP_DENOMINATION); // Bob got stableOne
        assertEq(stableOne.balanceOf(address(ztomic)), 0);
    }
}
