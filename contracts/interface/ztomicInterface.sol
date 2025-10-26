//SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

interface ZtomicInterface {

    // mapping (bytes32 => bool) public nullifierHashes;

    event deposited_initiator(bytes32 indexed order_id, bytes32 indexed _commitment, uint32 leafIndex, uint256 timestamp);
    event desposited_responder(bytes32 indexed _commitment, uint32 leafIndex, uint256 timestamp);

    event withdrawed_inititor(bytes32 indexed nullifierHash, bytes32 hashlock_nonce);
    event withdrawed_responder(bytes32 indexed nullifierHash);
  
    function deposit_initiator(bytes32 commitment, bytes32 order_id) external;

    function withdraw_initiator(bytes32 proof, bytes32 hashlock_nonce, bytes32 nullifier_hash, bytes32 root) external;

    function deposit_responder(bytes32 commitment) external;

    function withdraw_responder(bytes32 proof, bytes32 nullifier_hash, bytes32 root) external;
}