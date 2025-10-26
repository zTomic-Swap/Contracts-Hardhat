// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/// @title - A contract for sending/receiving tokens and data across chains with message tracking and acknowledgment.
contract CCIPTokenAndMessageTransferer is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    //=================================================
    //            STATE & DATA STRUCTURES
    //=================================================

    // Enum to track the status of messages sent via CCIP.
    enum MessageStatus {
        NotSent, // 0
        Sent, // 1
        ProcessedOnDestination // 2
    }

    // Struct to store the status and acknowledger message ID of a sent message.
    struct MessageInfo {
        MessageStatus status;
        bytes32 acknowledgerMessageId;
    }

    // Mapping to keep track of message IDs to their info.
    mapping(bytes32 => MessageInfo) public messagesInfo;

    // Mappings for allowlisting chains and senders.
    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(address => bool) public allowlistedSenders;

    // State variables to store details of the last received message.
    bytes32 private s_lastReceivedMessageId;
    address private s_lastReceivedTokenAddress;
    uint256 private s_lastReceivedTokenAmount;
    string private s_lastReceivedText;

    IERC20 private s_linkToken;

    //=================================================
    //                  ERRORS
    //=================================================
    error NotEnoughBalance(uint256 currentBalance, uint256 requiredBalance);
    error NothingToWithdraw();
    error DestinationChainNotAllowed(uint64 destinationChainSelector);
    error SourceChainNotAllowed(uint64 sourceChainSelector);
    error SenderNotAllowed(address sender);
    error InvalidReceiverAddress();
    // Errors for message tracking
    error MessageWasNotSentByThisContract(bytes32 msgId);
    error MessageHasAlreadyBeenProcessedOnDestination(bytes32 msgId);


    //=================================================
    //                   EVENTS
    //=================================================

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

    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        string text,
        address token,
        uint256 tokenAmount
    );

    // Event for when an acknowledgment is received
    event MessageProcessedOnDestination(
        bytes32 indexed acknowledgerMsgId,
        bytes32 indexed originalMsgId,
        uint64 indexed sourceChainSelector,
        address sender
    );


    //=================================================
    //                 CONSTRUCTOR
    //=================================================

    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
    }

    //=================================================
    //             MESSAGE SENDING LOGIC
    //=================================================

    /// @notice Sends data and transfers tokens to a receiver on the destination chain, paying fees in LINK.
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount
    )
        external
        // onlyOwner
        // onlyAllowlistedDestinationChain(_destinationChainSelector)
        // validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            _token,
            _amount,
            address(s_linkToken)
        );
        messageId = _sendMessage( _destinationChainSelector, evm2AnyMessage, _token, _amount);

        // ++ VITAL: Mark the message as Sent for tracking
        messagesInfo[messageId].status = MessageStatus.Sent;
    }

    /// @notice Sends only a text message without tokens, paying fees in LINK.
    function sendTextMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text
    )
        external
        // onlyOwner
        // onlyAllowlistedDestinationChain(_destinationChainSelector)
        // validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            address(0), // No token
            0,          // No amount
            address(s_linkToken)
        );
        messageId = _sendMessage(_destinationChainSelector, evm2AnyMessage, address(0), 0);

        // ++ VITAL: Mark the message as Sent for tracking
        messagesInfo[messageId].status = MessageStatus.Sent;
    }


    /// @dev Internal function to handle the common logic of sending a CCIP message.
    function _sendMessage(
        uint64 _destinationChainSelector,
        Client.EVM2AnyMessage memory _evm2AnyMessage,
        address _token,
        uint256 _amount
    ) private returns (bytes32 messageId) {
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(_destinationChainSelector, _evm2AnyMessage);

        uint256 requiredLinkBalance = fees;
        if (_token == address(s_linkToken)) {
            requiredLinkBalance += _amount;
        }

        if (requiredLinkBalance > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), requiredLinkBalance);
        }

        s_linkToken.approve(address(router), requiredLinkBalance);

        if (_token != address(0) && _token != address(s_linkToken)) {
            uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
            if (_amount > tokenBalance) {
                revert NotEnoughBalance(tokenBalance, _amount);
            }
            IERC20(_token).approve(address(router), _amount);
        }

        messageId = router.ccipSend(_destinationChainSelector, _evm2AnyMessage);

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            abi.decode(_evm2AnyMessage.receiver, (address)),
            abi.decode(_evm2AnyMessage.data, (string)),
            _token,
            _amount,
            address(s_linkToken),
            fees
        );

        return messageId;
    }

    //=================================================
    //         MESSAGE RECEIVING & ACKNOWLEDGING
    //=================================================

    /**
     * @dev Main entry point for receiving CCIP messages. It intelligently handles two cases:
     * 1. If data.length == 32, it treats the message as an ACKNOWLEDGMENT for a message previously sent.
     * 2. Otherwise, it treats it as a NEW INCOMING MESSAGE, processes it, and sends an acknowledgment back.
     */
    function _ccipReceive(Client.Any2EVMMessage memory _any2EvmMessage)
        internal
        override
        // onlyAllowlisted(
        //     _any2EvmMessage.sourceChainSelector,
        //     abi.decode(_any2EvmMessage.sender, (address))
        // )
    {
        // Case 1: The incoming data is 32 bytes long, which we interpret as an acknowledgment.
        if (_any2EvmMessage.data.length == 32) {
            _handleAcknowledgment(_any2EvmMessage);
        }
        // Case 2: The incoming data is not 32 bytes, so it's a new message with text and possibly tokens.
        else {
            _handleNewMessage(_any2EvmMessage);
        }
    }

    /**
     * @dev Processes an acknowledgment message.
     * It updates the status of the original message to `ProcessedOnDestination`.
     */
    function _handleAcknowledgment(Client.Any2EVMMessage memory _any2EvmMessage) private {
        bytes32 originalMsgId = abi.decode(_any2EvmMessage.data, (bytes32));

        if (messagesInfo[originalMsgId].status == MessageStatus.Sent) {
            messagesInfo[originalMsgId].status = MessageStatus.ProcessedOnDestination;
            messagesInfo[originalMsgId].acknowledgerMessageId = _any2EvmMessage.messageId;

            emit MessageProcessedOnDestination(
                _any2EvmMessage.messageId,
                originalMsgId,
                _any2EvmMessage.sourceChainSelector,
                abi.decode(_any2EvmMessage.sender, (address))
            );
        } else if (messagesInfo[originalMsgId].status == MessageStatus.ProcessedOnDestination) {
            revert MessageHasAlreadyBeenProcessedOnDestination(originalMsgId);
        } else {
            revert MessageWasNotSentByThisContract(originalMsgId);
        }
    }

    /**
     * @dev Processes a new incoming message, stores its details, and sends an acknowledgment back.
     */
    function _handleNewMessage(Client.Any2EVMMessage memory _any2EvmMessage) private {
        // Process and store the received message details
        s_lastReceivedMessageId = _any2EvmMessage.messageId;
        s_lastReceivedText = abi.decode(_any2EvmMessage.data, (string));
        s_lastReceivedTokenAddress = address(0);
        s_lastReceivedTokenAmount = 0;

        if (_any2EvmMessage.destTokenAmounts.length > 0) {
            s_lastReceivedTokenAddress = _any2EvmMessage.destTokenAmounts[0].token;
            s_lastReceivedTokenAmount = _any2EvmMessage.destTokenAmounts[0].amount;
        }

        emit MessageReceived(
            _any2EvmMessage.messageId,
            _any2EvmMessage.sourceChainSelector,
            abi.decode(_any2EvmMessage.sender, (address)),
            s_lastReceivedText,
            s_lastReceivedTokenAddress,
            s_lastReceivedTokenAmount
        );

        // Now, send an acknowledgment back to the sender
        _sendAcknowledgment(
            _any2EvmMessage.messageId, // The ID of the message we are acknowledging
            abi.decode(_any2EvmMessage.sender, (address)), // The original sender's address
            _any2EvmMessage.sourceChainSelector // The original sender's chain
        );
    }

    /**
     * @dev Constructs and sends an acknowledgment message back to the original sender.
     * This logic is adapted from the Acknowledger contract.
     */
    function _sendAcknowledgment(
        bytes32 _messageIdToAcknowledge,
        address _originalSenderAddress,
        uint64 _originalSenderChainSelector
    ) private {
        Client.EVM2AnyMessage memory ackMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_originalSenderAddress),
            data: abi.encode(_messageIdToAcknowledge), // The data is the ID of the message we received
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({ gasLimit: 200_000, allowOutOfOrderExecution: true })
            ),
            feeToken: address(s_linkToken)
        });

        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(_originalSenderChainSelector, ackMessage);

        if (fees > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }

        s_linkToken.approve(address(router), fees);
        router.ccipSend(_originalSenderChainSelector, ackMessage);
        // Note: You could emit an "AcknowledgmentSent" event here if desired.
    }


    //=================================================
    //                  HELPERS
    //=================================================

    function _buildCCIPMessage(
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts;
        if (_token != address(0) && _amount > 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](0);
        }

        return Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encode(_text),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({ gasLimit: 200_000, allowOutOfOrderExecution: true })
            ),
            feeToken: _feeTokenAddress
        });
    }

    function getLastReceivedMessageDetails() public view returns (
        bytes32 messageId,
        string memory text,
        address tokenAddress,
        uint256 tokenAmount
    ) {
        return (
            s_lastReceivedMessageId,
            s_lastReceivedText,
            s_lastReceivedTokenAddress,
            s_lastReceivedTokenAmount
        );
    }

    //=================================================
    //           ADMIN & WITHDRAWAL
    //=================================================
    // (Modifiers and functions for allowlisting and withdrawal are kept as they were)

    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector])
            revert DestinationChainNotAllowed(_destinationChainSelector);
        _;
    }

    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert SourceChainNotAllowed(_sourceChainSelector);
        if (!allowlistedSenders[_sender]) revert SenderNotAllowed(_sender);
        _;
    }

    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external /*onlyOwner*/ {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external /*onlyOwner*/ {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    function allowlistSender(address _sender, bool allowed) external /*onlyOwner*/ {
        allowlistedSenders[_sender] = allowed;
    }

    function withdrawToken(address _beneficiary, address _token) public /*onlyOwner*/ {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount == 0) revert NothingToWithdraw();
        IERC20(_token).safeTransfer(_beneficiary, amount);
    }
}