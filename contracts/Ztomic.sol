// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IncrementalMerkleTree} from "./IncrementalMerkleTree.sol";
import {Poseidon2} from "poseidon2-evm/src/Poseidon2.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IProgrammableTokenTransfers} from "./interface/IProgrammableTokenTransfers.sol";
import {CCIPTokenTransfererBytes} from "./ccip/CCIPTokenTransfererBytes.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IVerifier} from "./interface/IVerifier.sol";
//poseidon2-evm
/**
 * @title Ztomic
 * @notice A contract for managing a Zero-Knowledge Merkle tree of commitments.
 */
contract Ztomic is IncrementalMerkleTree, CCIPTokenTransfererBytes {
    mapping(bytes32 => bool) public s_nullifierHashes;
    mapping(bytes32 => bool) public s_commitments;
    mapping(uint32 => bytes32) public s_sharedRootsMapping;
    mapping(bytes32 => bool) public s_sharedNullifierHashes;
    IERC20 public s_stableOne;
    IERC20 public s_stableTwo;
    uint256 public SWAP_DENOMINATION = 1e6;
    IProgrammableTokenTransfers public ztomic_ccip_router;
    uint32 public SHARED_ROOT_HISTORY_SIZE = 30;
    uint32 public s_currentSharedRootIndex = 0;
    uint64[5] public destinationChainSelectors;
    IVerifier public verifierA;
    IVerifier public verifierB;

    error Ztomic_CommitmentAlreadyExists();
    error Ztomic__NoteAlreadySpent(bytes32 nullifierHash);
    error Ztomic__UnknownRoot(bytes32 root);
    error Ztomic__InvalidWithdrawProof();
    event deposited_initiator(bytes32 indexed _order_id_hash, bytes32 hashlock);
    event withdrawal_initiator(
        bytes32 indexed _order_id_hash,
        bytes32 _hashlock_nonce
    );
    event deposited_responder(bytes32 indexed _commitment);
    event withdrawal_responder(bytes32 indexed commitment);

    /**
     * @notice Sets up the contract with a fixed tree depth and a Poseidon hasher instance.
     * @param depth The desired depth of the Merkle tree (e.g., 20).
     * @param hasher The address of the deployed Poseidon2 hasher contract.
     */
    constructor(
        uint32 depth,
        Poseidon2 hasher,
        address stableOneAddress,
        address stableTwoAddress,
        address _ztomic_ccip_router,
        address _linkTokenAddress,
        uint64 _destinationChainSelector,
        address _verifierA,
        address _verifierB
    )
        IncrementalMerkleTree(depth, hasher)
        CCIPTokenTransfererBytes(_ztomic_ccip_router, _linkTokenAddress)
    {
        s_stableOne = IERC20(stableOneAddress);
        s_stableTwo = IERC20(stableTwoAddress);
        ztomic_ccip_router = IProgrammableTokenTransfers(_ztomic_ccip_router);
        destinationChainSelectors[0] = _destinationChainSelector;
        verifierA = IVerifier(_verifierA);
        verifierB = IVerifier(_verifierB);
    }

    /**
     * @notice Inserts a new leaf (commitment) into the Merkle tree.
     * @dev This function calls the internal `_insert` function from the parent
     * IncrementalMerkleTree contract to add the leaf and update the root.
     * @param _commitment The cryptographic commitment to be added as a leaf.
     */
    function deposit_initiator(
        bytes32 _commitment,
        bytes32 _order_id_hash,
        bytes32 _hashlock,
        bool _crossChain,
        address _destinationZtomicAddress
    ) public {
        if (s_commitments[_commitment] == true) {
            revert Ztomic_CommitmentAlreadyExists();
        }

        s_stableOne.transferFrom(msg.sender, address(this), SWAP_DENOMINATION);

        s_commitments[_commitment] = true;

        _insert(_commitment);

        if (_crossChain)
            sendMessagePayLINK(
                destinationChainSelectors[0],
                _destinationZtomicAddress,
                getLatestRoot(),
                address(s_stableOne),
                SWAP_DENOMINATION
            );

        emit deposited_initiator(_order_id_hash, _hashlock);
    }

    function withdraw_initiator(
        bytes calldata _proof,
        bytes32 _nullifierHash,
        bytes32 _root,
        bytes32 _hashlock_nonce,
        bytes32 _order_id_hash,
        address _recipient
    ) public {
        if (
            s_nullifierHashes[_nullifierHash] ||
            s_sharedNullifierHashes[_nullifierHash]
        ) {
            revert Ztomic__NoteAlreadySpent(_nullifierHash);
        }

        if (!isKnownRoot(_root) && !isKnownSharedRoot(_root)) {
            revert Ztomic__UnknownRoot(_root);
        }

        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _hashlock_nonce;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = _root;
        // if (!verifierA.verify(_proof, publicInputs)) {
        //     revert Ztomic__InvalidWithdrawProof();
        // }

        s_nullifierHashes[_nullifierHash] = true;

        s_stableTwo.transfer(_recipient, SWAP_DENOMINATION);

        emit withdrawal_initiator(_order_id_hash, _hashlock_nonce);
    }

    function deposit_responder(
        bytes32 _commitment,
        bool _crossChain,
        address _destinationZtomicAddress
    ) public {
        if (s_commitments[_commitment] == true) {
            revert Ztomic_CommitmentAlreadyExists();
        }

        s_stableTwo.transferFrom(msg.sender, address(this), SWAP_DENOMINATION);

        s_commitments[_commitment] = true;

        _insert(_commitment);

        if (_crossChain)
            sendMessagePayLINK(
                destinationChainSelectors[0],
                _destinationZtomicAddress,
                getLatestRoot(),
                address(s_stableTwo),
                SWAP_DENOMINATION
            );

        emit deposited_responder(_commitment);
    }

    function withdraw_responder(
        bytes calldata _proof,
        bytes32 _nullifierHash,
        bytes32 _root,
        address _recipient
    ) public {
        if (
            s_nullifierHashes[_nullifierHash] ||
            s_sharedNullifierHashes[_nullifierHash]
        ) {
            revert Ztomic__NoteAlreadySpent(_nullifierHash);
        }

        if (!isKnownRoot(_root) && !isKnownSharedRoot(_root)) {
            revert Ztomic__UnknownRoot(_root);
        }

        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = _nullifierHash;
        publicInputs[1] = _root;

        // if (!verifierB.verify(_proof, publicInputs)) {
        //     revert Ztomic__InvalidWithdrawProof();
        // }

        s_nullifierHashes[_nullifierHash] = true;

        s_stableOne.transfer(_recipient, SWAP_DENOMINATION);
    }
    /**
     * @notice Overrides the parent's CCIP receive function to add custom logic.
     * @dev This function is triggered when a cross-chain message arrives.
     * It decodes the incoming Merkle root and adds it to the shared root history.
     * Then, it calls the parent's implementation to handle event logging.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal virtual override {
        // Custom logic for Ztomic: the received data is a shared Merkle root.
        bytes32 sharedRoot = abi.decode(any2EvmMessage.data, (bytes32));

        // Add the new root to our history of shared roots from other chains.
        updateSharedRoot(sharedRoot);

        // Call the parent contract's _ccipReceive function to ensure its logic
        // (like emitting MessageReceived event) still runs.
        super._ccipReceive(any2EvmMessage);
    }

    function updateNullifierHashStorage(bytes32 _nullifierHash) internal {
        s_nullifierHashes[_nullifierHash] = true;
    }

    function updateSharedRoot(bytes32 _commitment) internal {
        s_currentSharedRootIndex =
            (s_currentSharedRootIndex + 1) %
            SHARED_ROOT_HISTORY_SIZE;
        s_sharedRootsMapping[s_currentSharedRootIndex] = _commitment;
    }

    function isKnownSharedRoot(bytes32 _root) public view returns (bool) {
        // check if they are trying to bypass the check by passing a zero root which is the defualt value
        if (_root == bytes32(0)) {
            return false;
        }
        uint32 m_currentSharedRootIndex = s_currentSharedRootIndex; // cash the result so we don't have to read it multiple times
        uint32 i = m_currentSharedRootIndex;
        do {
            if (_root == s_sharedRootsMapping[i]) {
                return true; // the root is present in the history
            }
            if (i == 0) {
                i = SHARED_ROOT_HISTORY_SIZE; // we have got to the end of the array and need to wrap around
            }
            i--;
        } while (i != s_currentSharedRootIndex); // once we get back to the current root index, we are done
        return false; // the root is not present in the history
    }
}
