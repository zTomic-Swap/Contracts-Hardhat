// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

/// @title - A simple messenger contract for transferring/receiving tokens and bytes32 data across chains.
contract CCIPTokenTransfererBytes is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    // --- Errors (Unchanged) ---
    error NotEnoughBalance(uint256 currentBalance, uint256 requiredBalance);
    error NothingToWithdraw();
    error FailedToWithdrawEth(address owner, address target, uint256 value);
    error DestinationChainNotAllowed(uint64 destinationChainSelector);
    error SourceChainNotAllowed(uint64 sourceChainSelector);
    error SenderNotAllowed(address sender);
    error InvalidReceiverAddress();

    // --- Events (Updated from string to bytes32) ---
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        bytes32 data, // <-- Changed from string
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        bytes32 data, // <-- Changed from string
        address token,
        uint256 tokenAmount
    );

    // --- State Variables (Updated from string to bytes32) ---
    bytes32 private s_lastReceivedMessageId;
    address private s_lastReceivedTokenAddress;
    uint256 private s_lastReceivedTokenAmount;
    bytes32 private s_lastReceivedData; // <-- Changed from string

    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(address => bool) public allowlistedSenders;

    IERC20 private s_linkToken;

    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
    }

    // --- Modifiers & Admin Functions (Unchanged) ---
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
    ) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    function allowlistSourceChain(
        uint64 _sourceChainSelector,
        bool allowed
    ) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    function allowlistSender(address _sender, bool allowed) external onlyOwner {
        allowlistedSenders[_sender] = allowed;
    }

    /// @notice Sends bytes32 data and transfers tokens, paying fees in LINK.
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes32 _data, // <-- Changed from string
        address _token,
        uint256 _amount
    )
        internal
        returns (
            // Access controls commented out for testing
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

        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

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

        if (_token != address(s_linkToken) && _token != address(0)) {
            uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
            if (_amount > tokenBalance) {
                revert NotEnoughBalance(tokenBalance, _amount);
            }
            IERC20(_token).approve(address(router), _amount);
        }

        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _data, // <-- Changed from string
            _token,
            _amount,
            address(s_linkToken),
            fees
        );

        return messageId;
    }

    /// @notice Handles a received CCIP message.
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        virtual
        override
    // onlyAllowlisted(...) // Access control commented out
    {
        s_lastReceivedMessageId = any2EvmMessage.messageId;
        s_lastReceivedData = abi.decode(any2EvmMessage.data, (bytes32)); // <-- Changed from string

        s_lastReceivedTokenAddress = address(0);
        s_lastReceivedTokenAmount = 0;

        // Handle token transfer only if tokens are included in the message
        if (any2EvmMessage.destTokenAmounts.length > 0) {
            s_lastReceivedTokenAddress = any2EvmMessage
                .destTokenAmounts[0]
                .token;
            s_lastReceivedTokenAmount = any2EvmMessage
                .destTokenAmounts[0]
                .amount;
        }

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            s_lastReceivedData, // <-- Changed from string
            s_lastReceivedTokenAddress,
            s_lastReceivedTokenAmount
        );
    }

    /// @notice Returns the details of the last received message.
    function getLastReceivedMessageDetails()
        public
        view
        returns (
            bytes32 messageId,
            bytes32 data, // <-- Changed from string
            address tokenAddress,
            uint256 tokenAmount
        )
    {
        return (
            s_lastReceivedMessageId,
            s_lastReceivedData, // <-- Changed from string
            s_lastReceivedTokenAddress,
            s_lastReceivedTokenAmount
        );
    }

    /// @dev Constructs a CCIP message with bytes32 data.
    function _buildCCIPMessage(
        address _receiver,
        bytes32 _data, // <-- Changed from string
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
                data: abi.encode(_data), // <-- Changed from string
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

    // --- Withdrawal Functions (Unchanged) ---
    receive() external payable {}

    function withdraw(address _beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        (bool sent, ) = _beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount == 0) revert NothingToWithdraw();
        IERC20(_token).safeTransfer(_beneficiary, amount);
    }
}
