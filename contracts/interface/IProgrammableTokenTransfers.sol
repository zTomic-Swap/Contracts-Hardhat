// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IProgrammableTokenTransfers
 * @dev Interface for the ProgrammableTokenTransfers contract.
 * It includes all external and public functions, events, and custom errors.
 */
interface IProgrammableTokenTransfers {
    // ═══════════════════════════════════════════
    //                      EVENTS
    // ═══════════════════════════════════════════

    /**
     * @dev Emitted when a message is sent to another chain.
     * @param messageId The unique ID of the CCIP message.
     * @param destinationChainSelector The chain selector of the destination chain.
     * @param receiver The address of the receiver on the destination chain.
     * @param text The text being sent.
     * @param token The token address that was transferred.
     * @param tokenAmount The token amount that was transferred.
     * @param feeToken The token address used to pay CCIP fees.
     * @param fees The fees paid for sending the message.
     */
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        string text,
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    /**
     * @dev Emitted when a message is received from another chain.
     * @param messageId The unique ID of the CCIP message.
     * @param sourceChainSelector The chain selector of the source chain.
     * @param sender The address of the sender from the source chain.
     * @param text The text that was received.
     * @param token The token address that was transferred.
     * @param tokenAmount The token amount that was transferred.
     */
    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        string text,
        address token,
        uint256 tokenAmount
    );

    // ═══════════════════════════════════════════
    //                  CUSTOM ERRORS
    // ═══════════════════════════════════════════

    error NotEnoughBalance(uint256 currentBalance, uint256 requiredBalance);
    error NothingToWithdraw();
    error FailedToWithdrawEth(address owner, address target, uint256 value);
    error DestinationChainNotAllowed(uint64 destinationChainSelector);
    error SourceChainNotAllowed(uint64 sourceChainSelector);
    error SenderNotAllowed(address sender);
    error InvalidReceiverAddress();

    // ═══════════════════════════════════════════
    //                 VIEW FUNCTIONS
    // ═══════════════════════════════════════════

    /**
     * @dev Returns true if the destination chain is allowlisted.
     * @param destinationChainSelector The selector of the destination chain.
     * @return bool The allowlist status.
     */
    function allowlistedDestinationChains(uint64 destinationChainSelector)
        external
        view
        returns (bool);

    /**
     * @dev Returns true if the source chain is allowlisted.
     * @param sourceChainSelector The selector of the source chain.
     * @return bool The allowlist status.
     */
    function allowlistedSourceChains(uint64 sourceChainSelector)
        external
        view
        returns (bool);

    /**
     * @dev Returns true if the sender address is allowlisted.
     * @param sender The address of the sender.
     * @return bool The allowlist status.
     */
    function allowlistedSenders(address sender) external view returns (bool);

    /**
     * @notice Returns the details of the last CCIP received message.
     * @return messageId The ID of the last received CCIP message.
     * @return text The text of the last received CCIP message.
     * @return tokenAddress The address of the token in the last CCIP received message.
     * @return tokenAmount The amount of the token in the last CCIP received message.
     */
    function getLastReceivedMessageDetails()
        external
        view
        returns (
            bytes32 messageId,
            string memory text,
            address tokenAddress,
            uint256 tokenAmount
        );

    // ═══════════════════════════════════════════
    //              EXTERNAL FUNCTIONS
    // ═══════════════════════════════════════════

    /**
     * @dev Updates the allowlist status of a destination chain.
     * @param _destinationChainSelector The selector of the destination chain.
     * @param allowed The allowlist status to be set.
     */
    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool allowed
    ) external;

    /**
     * @dev Updates the allowlist status of a source chain.
     * @param _sourceChainSelector The selector of the source chain.
     * @param allowed The allowlist status to be set.
     */
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed)
        external;

    /**
     * @dev Updates the allowlist status of a sender.
     * @param _sender The address of the sender.
     * @param allowed The allowlist status to be set.
     */
    function allowlistSender(address _sender, bool allowed) external;

    /**
     * @notice Sends data and tokens to a receiver on a destination chain, paying fees in LINK.
     * @param _destinationChainSelector The selector for the destination blockchain.
     * @param _receiver The address of the recipient on the destination blockchain.
     * @param _text The string data to be sent.
     * @param _token The address of the token to transfer.
     * @param _amount The amount of the token to transfer.
     * @return messageId The ID of the sent CCIP message.
     */
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount
    ) external returns (bytes32 messageId);

    /**
     * @notice Sends data and tokens to a receiver on a destination chain, paying fees in native currency.
     * @param _destinationChainSelector The selector for the destination blockchain.
     * @param _receiver The address of the recipient on the destination blockchain.
     * @param _text The string data to be sent.
     * @param _token The address of the token to transfer.
     * @param _amount The amount of the token to transfer.
     * @return messageId The ID of the sent CCIP message.
     */
    function sendMessagePayNative(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount
    ) external returns (bytes32 messageId);

    /**
     * @notice Withdraws the entire native currency balance from the contract.
     * @param _beneficiary The address to which the funds should be sent.
     */
    function withdraw(address _beneficiary) external;

    /**
     * @notice Withdraws the entire balance of a specific ERC20 token from the contract.
     * @param _beneficiary The address to which the tokens will be sent.
     * @param _token The contract address of the ERC20 token to be withdrawn.
     */
    function withdrawToken(address _beneficiary, address _token) external;
}