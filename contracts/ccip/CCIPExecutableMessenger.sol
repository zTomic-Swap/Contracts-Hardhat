// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

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

/// @title - A contract for executing cross-chain function calls and transferring tokens via CCIP.
contract CCIPExecutableMessenger is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    //=================================================
    //            STATE & DATA STRUCTURES
    //=================================================

    enum MessageStatus {
        NotSent,
        Sent,
        ProcessedOnDestination
    }

    struct MessageInfo {
        MessageStatus status;
        bytes32 acknowledgerMessageId;
    }

    mapping(bytes32 => MessageInfo) public messagesInfo;
    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(address => bool) public allowlistedSenders;

    // Example state variable to be changed by a cross-chain call
    string public lastUpdatedMessage;

    bytes32 private s_lastReceivedMessageId;
    address private s_lastReceivedTokenAddress;
    uint256 private s_lastReceivedTokenAmount;
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
    error MessageWasNotSentByThisContract(bytes32 msgId);
    error MessageHasAlreadyBeenProcessedOnDestination(bytes32 msgId);
    error CrossChainExecutionFailed(bytes32 messageId);

    //=================================================
    //                   EVENTS
    //=================================================
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        bytes data,
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        bytes data,
        address token,
        uint256 tokenAmount
    );

    event MessageProcessedOnDestination(
        bytes32 indexed acknowledgerMsgId,
        bytes32 indexed originalMsgId,
        uint64 indexed sourceChainSelector,
        address sender
    );

    event StoredMessageUpdated(string newMessage);

    event CrossChainCallExecuted(
        bytes32 indexed messageId,
        bytes data,
        bytes returnData
    );

    //=================================================
    //                 CONSTRUCTOR
    //=================================================
    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
    }

    //=================================================
    //           MESSAGE SENDING LOGIC
    //=================================================
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes calldata _data,
        address _token,
        uint256 _amount
    )
        external
        returns (
            // onlyOwner
            // onlyAllowlistedDestinationChain(_destinationChainSelector)
            // validateReceiver(_receiver)
            bytes32 messageId
        )
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _data,
            _token,
            _amount,
            address(s_linkToken)
        );
        messageId = _sendMessage(
            _destinationChainSelector,
            evm2AnyMessage,
            _token,
            _amount
        );
        messagesInfo[messageId].status = MessageStatus.Sent;
    }

    function _sendMessage(
        uint64 _destinationChainSelector,
        Client.EVM2AnyMessage memory _evm2AnyMessage,
        address _token,
        uint256 _amount
    ) private returns (bytes32 messageId) {
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(
            _destinationChainSelector,
            _evm2AnyMessage
        );
        uint256 requiredLinkBalance = fees;
        if (_token == address(s_linkToken)) {
            requiredLinkBalance += _amount;
        }
        if (requiredLinkBalance > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(
                s_linkToken.balanceOf(address(this)),
                requiredLinkBalance
            );
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
            _evm2AnyMessage.data,
            _token,
            _amount,
            address(s_linkToken),
            fees
        );
        return messageId;
    }

    //=================================================
    //       MESSAGE RECEIVING & EXECUTION
    //=================================================
    function _ccipReceive(
        Client.Any2EVMMessage memory _any2EvmMessage // onlyAllowlisted(
    ) internal override //     _any2EvmMessage.sourceChainSelector,
    //     abi.decode(_any2EvmMessage.sender, (address))
    // )
    {
        if (_any2EvmMessage.data.length == 32) {
            _handleAcknowledgment(_any2EvmMessage);
        } else {
            _handleNewMessage(_any2EvmMessage);
        }
    }

    function _handleAcknowledgment(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) private {
        bytes32 originalMsgId = abi.decode(_any2EvmMessage.data, (bytes32));
        if (messagesInfo[originalMsgId].status == MessageStatus.Sent) {
            messagesInfo[originalMsgId].status = MessageStatus
                .ProcessedOnDestination;
            messagesInfo[originalMsgId].acknowledgerMessageId = _any2EvmMessage
                .messageId;
            emit MessageProcessedOnDestination(
                _any2EvmMessage.messageId,
                originalMsgId,
                _any2EvmMessage.sourceChainSelector,
                abi.decode(_any2EvmMessage.sender, (address))
            );
        } else if (
            messagesInfo[originalMsgId].status ==
            MessageStatus.ProcessedOnDestination
        ) {
            revert MessageHasAlreadyBeenProcessedOnDestination(originalMsgId);
        } else {
            revert MessageWasNotSentByThisContract(originalMsgId);
        }
    }

    function _handleNewMessage(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) private {
        s_lastReceivedMessageId = _any2EvmMessage.messageId;
        s_lastReceivedTokenAddress = address(0);
        s_lastReceivedTokenAmount = 0;
        if (_any2EvmMessage.destTokenAmounts.length > 0) {
            s_lastReceivedTokenAddress = _any2EvmMessage
                .destTokenAmounts[0]
                .token;
            s_lastReceivedTokenAmount = _any2EvmMessage
                .destTokenAmounts[0]
                .amount;
        }
        emit MessageReceived(
            _any2EvmMessage.messageId,
            _any2EvmMessage.sourceChainSelector,
            abi.decode(_any2EvmMessage.sender, (address)),
            _any2EvmMessage.data,
            s_lastReceivedTokenAddress,
            s_lastReceivedTokenAmount
        );
        (bool success, bytes memory returnData) = address(this).call(
            _any2EvmMessage.data
        );
        if (!success) {
            revert CrossChainExecutionFailed(_any2EvmMessage.messageId);
        }
        emit CrossChainCallExecuted(
            _any2EvmMessage.messageId,
            _any2EvmMessage.data,
            returnData
        );
        _sendAcknowledgment(
            _any2EvmMessage.messageId,
            abi.decode(_any2EvmMessage.sender, (address)),
            _any2EvmMessage.sourceChainSelector
        );
    }

    function _sendAcknowledgment(
        bytes32 _messageIdToAcknowledge,
        address _originalSenderAddress,
        uint64 _originalSenderChainSelector
    ) private {
        Client.EVM2AnyMessage memory ackMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_originalSenderAddress),
            data: abi.encode(_messageIdToAcknowledge),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 200_000,
                    allowOutOfOrderExecution: true
                })
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
    }

    //=================================================
    //           EXAMPLE TARGET FUNCTION
    //=================================================
    function updateStoredMessage(string calldata _newMessage) external {
        lastUpdatedMessage = _newMessage;
        emit StoredMessageUpdated(_newMessage);
    }

    //=================================================
    //                   HELPERS
    //=================================================
    function _buildCCIPMessage(
        address _receiver,
        bytes calldata _data,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts;
        if (_token != address(0) && _amount > 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({
                token: _token,
                amount: _amount
            });
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](0);
        }
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver),
                data: _data,
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.GenericExtraArgsV2({
                        gasLimit: 200_000,
                        allowOutOfOrderExecution: true
                    })
                ),
                feeToken: _feeTokenAddress
            });
    }

    function getLastReceivedMessageDetails()
        public
        view
        returns (bytes32 messageId, address tokenAddress, uint256 tokenAmount)
    {
        return (
            s_lastReceivedMessageId,
            s_lastReceivedTokenAddress,
            s_lastReceivedTokenAmount
        );
    }

    //=================================================
    //           ADMIN & WITHDRAWAL
    //=================================================
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

    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool allowed
    ) external /*onlyOwner*/ {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    function allowlistSourceChain(
        uint64 _sourceChainSelector,
        bool allowed
    ) external /*onlyOwner*/ {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    function allowlistSender(
        address _sender,
        bool allowed
    ) external /*onlyOwner*/ {
        allowlistedSenders[_sender] = allowed;
    }

    function withdrawToken(
        address _beneficiary,
        address _token
    ) public /*onlyOwner*/ {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount == 0) revert NothingToWithdraw();
        IERC20(_token).safeTransfer(_beneficiary, amount);
    }
}
