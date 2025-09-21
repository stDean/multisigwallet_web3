// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Multi-signature Wallet
 * @dev A contract that requires multiple approvals for transactions
 * @notice Allows a group of owners to collectively manage funds with enhanced security
 * @custom:security-contact security@example.com
 */
contract MultiSigWallet is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @dev Transaction structure to store transaction details
     * @param to Destination address of the transaction
     * @param value Amount of ETH to transfer
     * @param data Calldata for the transaction
     * @param executed Boolean indicating if the transaction has been executed
     * @param description Human-readable description of the transaction
     * @param confirmations Number of confirmations received for this transaction
     */
    struct Transaction {
        address to;
        uint96 value; // Reduced from uint256 to save gas (supports up to 79 billion ETH)
        bytes data;
        bool executed;
        string description;
        uint16 confirmations; // Reduced from uint256 (supports up to 65,535 confirmations)
    }

    // State variables
    address[] private s_owners;
    mapping(address => bool) private s_isOwner;
    uint256 private s_threshold;
    uint256 private s_transactionCount;
    // Removed s_requiredConfirmations as it's redundant with s_threshold
    // Removed s_executionNonce as it's not used in the current implementation

    // Mappings
    mapping(uint256 => Transaction) private s_transactions;
    mapping(uint256 => mapping(address => bool)) private s_isConfirmed;
    mapping(address => uint256) public s_executionNonce;

    // Events
    /**
     * @notice Emitted when a new transaction is submitted
     * @param txId ID of the submitted transaction
     * @param sender Address that submitted the transaction
     * @param to Destination address of the transaction
     * @param value Amount of ETH to transfer
     * @param data Calldata for the transaction
     * @param description Human-readable description of the transaction
     */
    event SubmitTransaction(
        uint256 indexed txId, address indexed sender, address indexed to, uint256 value, bytes data, string description
    );

    /**
     * @notice Emitted when a deposit is made to the wallet
     * @param amount Amount to be deposited
     * @param sender Address that confirmed the transaction
     * @param balance Balance of wallet
     */
    event Deposit(address indexed sender, uint256 amount, uint256 balance);

    /**
     * @notice Emitted when a transaction is confirmed by an owner
     * @param txId ID of the confirmed transaction
     * @param sender Address that confirmed the transaction
     */
    event ConfirmTransaction(uint256 indexed txId, address indexed sender);

    /**
     * @notice Emitted when a transaction is revoked by an owner
     * @param txId ID of the confirmed transaction
     * @param sender Address that confirmed the transaction
     */
    event RevokeConfirmation(uint256 indexed txId, address indexed sender);

    /**
     * @notice Emitted when a transaction execution
     * @param txId ID of the confirmed transaction
     * @param sender Address that confirmed the transaction
     */
    event ExecuteTransaction(uint256 indexed txId, address indexed sender);

    /**
     * @notice Emitted when a transaction execution is successful
     * @param txId ID of the confirmed transaction
     * @param sender Address that confirmed the transaction
     */
    event ExecuteTransactionSuccess(uint256 indexed txId, address indexed sender);

    /**
     * @notice Emitted when a new owner is added
     * @param newOwner Address of new owner to be added
     */
    event OwnerAdded(address indexed newOwner);

    event OwnerRemoved(address indexed removedOwner);
    event ThresholdChanged(uint256 newThreshold);

    // Errors
    /// @dev Error thrown when no owners are provided during initialization
    error MultiSigWallet__OwnersRequired();

    /// @dev Error thrown when an invalid threshold is provided
    error MultiSigWallet__InvalidThreshold();

    /// @dev Error thrown when a zero address is provided as an owner
    error MultiSigWallet__InvalidOwner();

    /// @dev Error thrown when duplicate owners are provided
    error MultiSigWallet__OwnerNotUnique();

    /// @dev Error thrown when a zero address is provided as a transaction target
    error MultiSigWallet__InvalidTargetAddress();

    /// @dev Error thrown when a non-owner tries to perform an owner-only operation
    error MultiSigWallet__CallerNotAOwner();

    /// @dev Error thrown when a transaction does not exist
    error MultiSigWallet__TransactionDoesNotExist();

    /// @dev Error thrown when a transaction has been executer
    error MultiSigWallet__TransactionAlreadyExecuted();

    /// @dev Error thrown when a transaction has been confirmed by a owner
    error MultiSigWallet__TransactionAlreadyConfirmedByThisOwner();

    /// @dev Error thrown when a transaction confirmations is less than or equal to threshold
    error MultiSigWallet__CannotExecuteTransactionWithoutEnoughConfirmations();

    /// @dev Error thrown when a transaction execution fails
    error MultiSigWallet__TransactionExecutionFailed();

    /// @dev Error thrown when a owner has not confirmed a transaction
    error MultiSigWallet__TransactionNotConfirmed();

    /// @dev Error thrown when a zero address is provided for a new owner
    error MultiSigWallet__InvalidOwnerAddress();

    /// @dev Error thrown when owner already exist
    error MultiSigWallet__OwnerAlreadyExist();

    /// @dev Error thrown when not an owner
    error MultiSigWallet__NotAnOwner();

    /// @dev Error thrown when owner is less than or equal to one
    error MultiSigWallet__CannotRemoveLastOwner();

    /// @dev Error thrown when owner is less than or equal to one
    error MultiSigWallet__OnlyCallableViaExecutedTransaction();

    // Modifiers
    /**
     * @dev Modifier to restrict access to owners only
     */
    modifier onlyOwners() {
        if (!s_isOwner[msg.sender]) revert MultiSigWallet__CallerNotAOwner();
        _;
    }

    /**
     * @dev Modifier to check if a transaction exists
     * @param _txId ID of the transaction to check
     */
    modifier txExists(uint256 _txId) {
        if (_txId >= s_transactionCount) revert MultiSigWallet__TransactionDoesNotExist();
        _;
    }

    /**
     * @dev Modifier to check if a transaction is not executed
     * @param _txId ID of the transaction
     */
    modifier notExecuted(uint256 _txId) {
        // Check if already executed
        if (s_transactions[_txId].executed) revert MultiSigWallet__TransactionAlreadyExecuted();
        _;
    }

    modifier notConfirmed(uint256 _txId) {
        if (s_isConfirmed[_txId][msg.sender]) revert MultiSigWallet__TransactionAlreadyConfirmedByThisOwner();
        _;
    }

    /**
     * @notice Receive function to allow ETH deposits
     * @dev Emits a Deposit event when ETH is received
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @notice Initialize the multisig wallet with owners and threshold
     * @dev Constructor sets up the initial owners and required confirmations
     * @param _owners Array of owner addresses
     * @param _threshold Minimum number of confirmations required for transactions
     * @custom:reverts MultiSigWallet__OwnersRequired if less than 2 owners provided
     * @custom:reverts MultiSigWallet__InvalidThreshold if threshold is invalid
     * @custom:reverts MultiSigWallet__InvalidOwner if zero address provided as owner
     * @custom:reverts MultiSigWallet__OwnerNotUnique if duplicate owners provided
     */
    constructor(address[] memory _owners, uint256 _threshold) {
        if (_owners.length < 2) revert MultiSigWallet__OwnersRequired();
        if (_threshold < 1 || _threshold > _owners.length) revert MultiSigWallet__InvalidThreshold();

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) revert MultiSigWallet__InvalidOwner();
            if (s_isOwner[owner]) revert MultiSigWallet__OwnerNotUnique();

            s_isOwner[owner] = true;
            s_owners.push(owner);
        }

        s_threshold = _threshold;
    }

    // MAIN FUNCTIONS

    /**
     * @notice Submit a new transaction for approval
     * @dev Creates a new transaction that requires multisig approval
     * @param _to Target address for the transaction
     * @param _value ETH value to send with the transaction
     * @param _data Calldata for the transaction
     * @param _description Description of the transaction for clarity
     * @return txId ID of the newly created transaction
     * @custom:reverts MultiSigWallet__InvalidTargetAddress if _to is address(0)
     */
    function submitTransaction(address _to, uint96 _value, bytes memory _data, string memory _description)
        public
        onlyOwners
        returns (uint256 txId)
    {
        if (_to == address(0)) revert MultiSigWallet__InvalidTargetAddress();

        txId = s_transactionCount;
        s_transactions[txId] = Transaction({
            to: _to,
            data: _data,
            confirmations: 0,
            executed: false,
            description: _description,
            value: _value
        });

        s_transactionCount += 1;

        emit SubmitTransaction(txId, msg.sender, _to, _value, _data, _description);

        // Auto-confirm by the submitter
        confirmTransaction(txId);
    }

    /**
     * @notice Confirm a transaction
     * @dev Allows an owner to confirm a pending transaction
     * @param _txId ID of the transaction to confirm
     * @custom:reverts MultiSigWallet__TransactionDoesNotExist if transaction doesn't exist
     */
    function confirmTransaction(uint256 _txId)
        public
        onlyOwners
        txExists(_txId)
        notExecuted(_txId)
        notConfirmed(_txId)
    {
        Transaction storage transaction = s_transactions[_txId];

        s_isConfirmed[_txId][msg.sender] = true;
        transaction.confirmations += 1;

        emit ConfirmTransaction(_txId, msg.sender);
    }

    /**
     * @notice Execute a confirmed transaction
     * @dev Executes a transaction once it has enough confirmations. Only owners can execute.
     * @param _txId ID of the transaction to execute
     * @custom:reverts MultiSigWallet__CannotExecuteTransactionWithoutEnoughConfirmations if confirmations < threshold
     * @custom:reverts MultiSigWallet__TransactionExecutionFailed if the external call fails
     * @custom:emits ExecuteTransaction on successful execution
     * @custom:emits ExecuteTransactionSuccess on successful external call
     */
    function executeTransaction(uint256 _txId) public nonReentrant onlyOwners txExists(_txId) notExecuted(_txId) {
        Transaction storage transaction = s_transactions[_txId];
        if (transaction.confirmations < s_threshold) {
            revert MultiSigWallet__CannotExecuteTransactionWithoutEnoughConfirmations();
        }

        transaction.executed = true;
        s_executionNonce[msg.sender] += 1;

        // Execute the transaction
        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);

        if (success) {
            emit ExecuteTransactionSuccess(_txId, msg.sender);
        } else {
            // Mark as not executed to allow retry
            transaction.executed = false;

            revert MultiSigWallet__TransactionExecutionFailed();
        }

        emit ExecuteTransaction(_txId, msg.sender);
    }

    /**
     * @notice Revoke a confirmation for a transaction
     * @dev Allows an owner to revoke their confirmation
     * @param _txId ID of the transaction to revoke confirmation for
     */
    function revokeConfirmation(uint256 _txId) public onlyOwners txExists(_txId) notExecuted(_txId) {
        if (!s_isConfirmed[_txId][msg.sender]) revert MultiSigWallet__TransactionNotConfirmed();

        s_isConfirmed[_txId][msg.sender] = false;
        s_transactions[_txId].confirmations -= 1;
        emit RevokeConfirmation(_txId, msg.sender);
    }

    /**
     * @notice Submit a transaction to add a new owner
     * @dev Creates a transaction that will add a new owner when executed
     * @param newOwner Address of the new owner to add
     * @return txId ID of the newly created transaction
     */
    function submitAddOwnerTransaction(address newOwner) external returns (uint256 txId) {
        if (newOwner == address(0)) revert MultiSigWallet__InvalidOwnerAddress();
        if (s_isOwner[newOwner]) revert MultiSigWallet__OwnerAlreadyExist();

        bytes memory data = abi.encodeWithSignature("addOwner(address)", newOwner);
        return submitTransaction(address(this), 0, data, "Add new owner");
    }

    /**
     * @notice Add a new owner
     * @dev This function should be called via a multisig transaction
     * @param newOwner Address of the new owner to add
     */
    function addOwner(address newOwner) external {
        // Only allow self-call (via executed transaction)
        if (msg.sender != address(this)) revert MultiSigWallet__OnlyCallableViaExecutedTransaction();
        if (newOwner == address(0)) revert MultiSigWallet__InvalidOwner();
        if (s_isOwner[newOwner]) revert MultiSigWallet__OwnerAlreadyExist();

        s_isOwner[newOwner] = true;
        s_owners.push(newOwner);

        emit OwnerAdded(newOwner);
    }

    /**
     * @notice Submit a transaction to remove an owner
     * @dev Creates a transaction that will remove an owner when executed
     * @param ownerToRemove Address of the owner to remove
     * @return txId ID of the newly created transaction
     */
    function submitRemoveOwnerTransaction(address ownerToRemove) external returns (uint256 txId) {
        if (!s_isOwner[ownerToRemove]) revert MultiSigWallet__NotAnOwner();
        if (s_owners.length <= 1) revert MultiSigWallet__CannotRemoveLastOwner();

        bytes memory data = abi.encodeWithSignature("removeOwner(address)", ownerToRemove);
        return submitTransaction(address(this), 0, data, "Remove owner");
    }

    /**
     * @notice Remove an owner
     * @dev This function should be called via a multisig transaction
     * @param ownerToRemove Address of the owner to remove
     */
    function removeOwner(address ownerToRemove) external {
        // Only allow self-call (via executed transaction)
        if (msg.sender != address(this)) revert MultiSigWallet__OnlyCallableViaExecutedTransaction();
        if (!s_isOwner[ownerToRemove]) revert MultiSigWallet__NotAnOwner();
        if (s_owners.length < 1) revert MultiSigWallet__CannotRemoveLastOwner();
        if (s_threshold > s_owners.length - 1) revert MultiSigWallet__InvalidThreshold();

        s_isOwner[ownerToRemove] = false;

        // Remove from owners array
        for (uint256 i = 0; i < s_owners.length; i++) {
            if (s_owners[i] == ownerToRemove) {
                s_owners[i] = s_owners[s_owners.length - 1];
                s_owners.pop();
                break;
            }
        }

        emit OwnerRemoved(ownerToRemove);
    }

    /**
     * @notice Submit a transaction to change the threshold
     * @dev Creates a transaction that will change the threshold when executed
     * @param newThreshold New threshold value
     * @return txId ID of the newly created transaction
     */
    function submitChangeThresholdTransaction(uint256 newThreshold) external returns (uint256 txId) {
        if (newThreshold < 1 || newThreshold > s_owners.length) revert MultiSigWallet__InvalidThreshold();

        bytes memory data = abi.encodeWithSignature("changeThreshold(uint256)", newThreshold);
        return submitTransaction(address(this), 0, data, "Change threshold");
    }

    /**
     * @notice Change the threshold
     * @dev This function should be called via a multisig transaction
     * @param newThreshold New threshold value
     */
    function changeThreshold(uint256 newThreshold) external {
        // Only allow self-call (via executed transaction)
        if (msg.sender != address(this)) revert MultiSigWallet__OnlyCallableViaExecutedTransaction();
        if (newThreshold < 1 || newThreshold > s_owners.length) revert MultiSigWallet__InvalidThreshold();

        s_threshold = newThreshold;
        emit ThresholdChanged(newThreshold);
    }

    // GETTER FUNCTIONS AND HELPERS

    /**
     * @notice Get the list of all wallet owners
     * @dev Returns an array of all addresses that are owners of this wallet
     * @return Array of owner addresses
     */
    function getOwners() external view returns (address[] memory) {
        return s_owners;
    }

    /**
     * @notice Get the current threshold value
     * @dev Returns the minimum number of confirmations required for transactions
     * @return Current threshold value
     */
    function getThreshold() external view returns (uint256) {
        return s_threshold;
    }

    /**
     * @notice Check if an address is a wallet owner
     * @dev Returns whether the specified address is an owner of this wallet
     * @param _owner Address to check
     * @return True if the address is an owner, false otherwise
     */
    function getIsWalletOwner(address _owner) external view returns (bool) {
        return s_isOwner[_owner];
    }

    /**
     * @notice Get the total number of transactions
     * @dev Returns the count of all transactions submitted to this wallet
     * @return Total number of transactions
     */
    function getTransactionCount() external view returns (uint256) {
        return s_transactionCount;
    }

    /**
     * @notice Get transaction details by ID
     * @dev Returns the transaction structure for a given transaction ID
     * @param _txId ID of the transaction to retrieve
     * @return Transaction details
     * @custom:reverts MultiSigWallet__TransactionDoesNotExist if transaction doesn't exist
     */
    function getTransactions(uint256 _txId) external view txExists(_txId) returns (Transaction memory) {
        return s_transactions[_txId];
    }

    /**
     * @notice Check if a user has confirmed a transaction
     * @dev Returns whether a specific user has confirmed a specific transaction
     * @param _txId ID of the transaction to check
     * @param _user Address of the user to check
     * @return True if the user has confirmed the transaction, false otherwise
     * @custom:reverts MultiSigWallet__TransactionDoesNotExist if transaction doesn't exist
     */
    function getIsConfirmed(uint256 _txId, address _user) external view txExists(_txId) returns (bool) {
        return s_isConfirmed[_txId][_user];
    }

    /**
     * @notice Get execution nonce
     * @dev Returns the nonce
     * @param _executor address of the executor
     * @return Nonce
     */
    function getExecutionNonce(address _executor) external view returns (uint256) {
        return s_executionNonce[_executor];
    }
}
