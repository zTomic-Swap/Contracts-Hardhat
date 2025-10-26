// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IncrementalMerkleTree} from "./IncrementalMerkleTree.sol";
import {Poseidon2} from "poseidon2-evm/src/Poseidon2.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IProgrammableTokenTransfers} from "./interface/IProgrammableTokenTransfers.sol";
import {CCIPTokenTransfererBytes} from "./ccip/CCIPTokenTransfererBytes.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IVerifier} from "./interface/IVerifier.sol";

/**
 * @title Ztomic
 * @notice An optimized contract for managing a Zero-Knowledge Merkle tree of commitments.
 */
contract ZtomicOptimized is IncrementalMerkleTree, CCIPTokenTransfererBytes {
    // --- OPTIMIZATION 1: State Variable Packing ---

    uint32 public SHARED_ROOT_HISTORY_SIZE = 30;
    uint32 public s_currentSharedRootIndex = 0;
    uint64 public SWAP_DENOMINATION = 1e6;

    // --- Other State Variables ---
    IERC20 public s_stableOne;
    IERC20 public s_stableTwo;
    IProgrammableTokenTransfers public ztomic_ccip_router;
    IVerifier public verifierA;
    IVerifier public verifierB;
    uint64[5] public destinationChainSelectors;

    // --- Mappings ---
    mapping(bytes32 => bool) public s_nullifierHashes;

    mapping(bytes32 => bool) public s_initiator_commitments;
    mapping(bytes32 => bool) public s_responder_commitments;

    mapping(uint32 => bytes32) public s_sharedRootsMapping;

    mapping(bytes32 => bool) public s_sharedNullifierHashes;

    error Ztomic_CommitmentAlreadyExists();
    error Ztomic__NoteAlreadySpent(bytes32 nullifierHash);
    error Ztomic__UnknownRoot(bytes32 root);
    error Ztomic__InvalidWithdrawProof();
    event deposited(
        bytes32 indexed _commitment,
        uint32 leafIndex,
        bytes32 indexed _order_id_hash,
        bytes32 hashlock,
        bytes32 ccipMessageId
    );
    event withdrawal_initiator(
        bytes32 indexed _order_id_hash,
        bytes32 _hashlock_nonce
    );

    event withdrawal_responder(address commitment);

    /**
     * @notice Sets up the contract.
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
     */
    function deposit_initiator(
        bytes32 _commitment,
        bytes32 _order_id_hash,
        bytes32 _hashlock,
        bool _crossChain,
        address _destinationZtomicAddress
    ) external {
        if (s_initiator_commitments[_commitment]) {
            revert Ztomic_CommitmentAlreadyExists();
        }

        uint64 denomination = SWAP_DENOMINATION;
        IERC20 stableOne = s_stableOne;

        stableOne.transferFrom(msg.sender, address(this), denomination);

        s_initiator_commitments[_commitment] = true;

        uint32 insertedIndex = _insert(_commitment);

        if (_crossChain) {
            bytes32 messageId = sendMessagePayLINK(
                destinationChainSelectors[0],
                _destinationZtomicAddress,
                getLatestRoot(),
                address(stableOne),
                denomination
            );

            emit deposited(
                _commitment,
                insertedIndex,
                _order_id_hash,
                _hashlock,
                messageId
            );
        }
        emit deposited(
            _commitment,
            insertedIndex,
            _order_id_hash,
            _hashlock,
            0x0
        );
    }

    function withdraw_initiator(
        bytes calldata _proof,
        bytes32 _nullifierHash,
        bytes32 _root,
        bytes32 _hashlock_nonce,
        bytes32 _order_id_hash,
        address _recipient
    ) external {
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

        if (!verifierA.verify(_proof, publicInputs)) {
            revert Ztomic__InvalidWithdrawProof();
        }

        s_nullifierHashes[_nullifierHash] = true;

        s_stableTwo.transfer(_recipient, SWAP_DENOMINATION);

        emit withdrawal_initiator(_order_id_hash, _hashlock_nonce);
    }

    function deposit_responder(
        bytes32 _commitment,
        bool _crossChain,
        address _destinationZtomicAddress
    ) external {
        if (s_responder_commitments[_commitment]) {
            revert Ztomic_CommitmentAlreadyExists();
        }

        uint64 denomination = SWAP_DENOMINATION;
        IERC20 stableTwo = s_stableTwo;

        stableTwo.transferFrom(msg.sender, address(this), denomination);

        s_responder_commitments[_commitment] = true;

        uint32 insertedIndex = _insert(_commitment);

        if (_crossChain) {
            bytes32 messageId = sendMessagePayLINK(
                destinationChainSelectors[0],
                _destinationZtomicAddress,
                getLatestRoot(),
                address(stableTwo),
                denomination
            );
            emit deposited(
                _commitment,
                insertedIndex,
                0x0,
                0x0,
                messageId
            );
        } else {
            emit deposited(_commitment, insertedIndex, 0x0, 0x0, 0x0);
        }
    }

    function withdraw_responder(
        bytes calldata _proof,
        bytes32 _nullifierHash,
        bytes32 _root,
        address _recipient
    ) external {
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
 
        if (!verifierB.verify(_proof, publicInputs)) {
            revert Ztomic__InvalidWithdrawProof();
        }

        s_nullifierHashes[_nullifierHash] = true;

        s_stableOne.transfer(_recipient, SWAP_DENOMINATION);

        emit withdrawal_responder(_recipient);
    }

    /**
     * @notice Overrides the parent's CCIP receive function to add custom logic.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal virtual override {
        bytes32 sharedRoot = abi.decode(any2EvmMessage.data, (bytes32));

        updateSharedRoot(sharedRoot);

        super._ccipReceive(any2EvmMessage);
    }

    function updateSharedRoot(bytes32 _commitment) internal {
        s_currentSharedRootIndex =
            (s_currentSharedRootIndex + 1) %
            SHARED_ROOT_HISTORY_SIZE;
        s_sharedRootsMapping[s_currentSharedRootIndex] = _commitment;
    }

    function isKnownSharedRoot(bytes32 _root) public view returns (bool) {
        if (_root == bytes32(0)) {
            return false;
        }

        uint32 currentIndex = s_currentSharedRootIndex;
        uint32 historySize = SHARED_ROOT_HISTORY_SIZE;

        uint32 i = currentIndex;
        do {
            if (_root == s_sharedRootsMapping[i]) {
                return true;
            }
            if (i == 0) {
                i = historySize;
            }
            i--;
        } while (i != currentIndex);
        return false;
    }
}
