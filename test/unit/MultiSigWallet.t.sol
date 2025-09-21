// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployMultiSigWallet, HelperConfig} from "script/DeployMultiSigWallet.s.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

// Helper contract for testing failed external calls
contract RevertingContract {
    fallback() external payable {
        revert("RevertingContract: Always reverts");
    }
}

/**
 * @title MultiSigWalletTest
 * @dev Comprehensive test suite for MultiSigWallet contract
 * @notice Tests the functionality and edge cases of the MultiSigWallet implementation
 */
contract MultiSigWalletTest is Test {
    /// @dev Instance of the deployer contract
    DeployMultiSigWallet public deployer;

    /// @dev Instance of the MultiSigWallet contract under test
    MultiSigWallet public wallet;

    /// @dev Instance of the helper configuration contract
    HelperConfig public helperConfig;

    /// @dev Network configuration for the current test environment
    HelperConfig.NetworkConfig public config;

    /// @dev A non-owner address for testing access control
    address nonOwner = makeAddr("nonOwner");

    /// @dev Test recipient address for transactions
    address recipient = makeAddr("recipient");

    /// @dev Test transaction parameters
    uint96 testValue = 1 ether;
    bytes testData = hex"1234";
    string testDescription = "Test transaction";

    /**
     * @notice Set up the test environment before each test
     * @dev Deploys the MultiSigWallet contract and retrieves its configuration
     */
    function setUp() external {
        deployer = new DeployMultiSigWallet();
        (wallet, helperConfig) = deployer.run();
        config = helperConfig.getConfig();
    }

    modifier fundWallet() {
        vm.deal(address(wallet), testValue);

        _;
    }

    // CONSTRUCTION TESTS

    /**
     * @notice Test that constructor sets the correct owners
     * @dev Verifies that the owners array is correctly initialized
     */
    function test_ConstructorSetsCorrectOwners() public view {
        // Check that owners are set correctly
        address[] memory owners = wallet.getOwners();
        assertEq(owners.length, config.owners.length);
    }

    /**
     * @notice Test that constructor sets the correct threshold
     * @dev Verifies that the threshold is correctly initialized
     */
    function test_ConstructorSetsCorrectThreshold() public view {
        // Check that threshold is set correctly
        assertEq(wallet.getThreshold(), config.threshold);
    }

    /**
     * @notice Test that constructor marks owner addresses as owners
     * @dev Verifies that all configured owners are correctly recognized as owners
     */
    function test_ConstructorOwnersAreMarkedAsOwners() public view {
        // Check that owner addresses are marked as owners
        for (uint256 i = 0; i < config.owners.length; i++) {
            assertTrue(wallet.getIsWalletOwner(config.owners[i]));
        }
    }

    /**
     * @notice Test that constructor doesn't mark non-owners as owners
     * @dev Verifies that non-owner addresses are correctly not recognized as owners
     */
    function test_ConstructorNonOwnersAreNotMarkedAsOwners() public view {
        // Check that non-owner addresses are not marked as owners
        assertFalse(wallet.getIsWalletOwner(nonOwner));
    }

    /**
     * @notice Test that constructor reverts when no owners are provided
     * @dev Verifies the contract reverts with the expected error when no owners are provided
     */
    function test_ConstructorRevertsWhenNoOwners() public {
        // Test that constructor reverts with no owners
        address[] memory emptyOwners = new address[](0);

        vm.expectRevert(MultiSigWallet.MultiSigWallet__OwnersRequired.selector);
        new MultiSigWallet(emptyOwners, 1);
    }

    /**
     * @notice Test that constructor reverts when threshold is zero
     * @dev Verifies the contract reverts with the expected error when threshold is zero
     */
    function test_ConstructorRevertsWhenThresholdZero() public {
        vm.expectRevert(MultiSigWallet.MultiSigWallet__InvalidThreshold.selector);
        new MultiSigWallet(config.owners, 0);
    }

    /**
     * @notice Test that constructor reverts when threshold exceeds number of owners
     * @dev Verifies the contract reverts with the expected error when threshold is too high
     */
    function test_ConstructorRevertsWhenThresholdGreaterThanOwners() public {
        vm.expectRevert(MultiSigWallet.MultiSigWallet__InvalidThreshold.selector);
        new MultiSigWallet(config.owners, type(uint256).max);
    }

    /**
     * @notice Test that constructor reverts when owner is zero address
     * @dev Verifies the contract reverts with the expected error when a zero address is provided as owner
     */
    function test_ConstructorRevertsWhenOwnerIsZeroAddress() public {
        // Test that constructor reverts with zero address owner
        address[] memory owners = new address[](2);
        owners[0] = config.owners[0];
        owners[1] = address(0);

        uint256 threshold = 2;

        vm.expectRevert(MultiSigWallet.MultiSigWallet__InvalidOwner.selector);
        new MultiSigWallet(owners, threshold);
    }

    /**
     * @notice Test that constructor reverts when duplicate owners are provided
     * @dev Verifies the contract reverts with the expected error when duplicate owners are provided
     */
    function test_ConstructorRevertsWhenDuplicateOwners() public {
        // Test that constructor reverts with duplicate owners
        address[] memory owners = new address[](2);
        owners[0] = config.owners[0];
        owners[1] = config.owners[0]; // Duplicate
        uint256 threshold = 2;

        vm.expectRevert(MultiSigWallet.MultiSigWallet__OwnerNotUnique.selector);
        new MultiSigWallet(owners, threshold);
    }

    /**
     * @notice Test that deployer returns valid contract instances
     * @dev Verifies that the deployer returns non-zero addresses for both wallet and helper config
     */
    function test_DeployerReturnsValidContract() public view {
        // Test that the deployer returns a valid contract
        assertTrue(address(wallet) != address(0));
        assertTrue(address(helperConfig) != address(0));
    }

    /**
     * @notice Test that helper config returns valid configuration
     * @dev Verifies that the helper config returns a valid configuration with proper owners and threshold
     */
    function test_HelperConfigReturnsValidConfig() public view {
        // Test that helper config returns valid configuration
        assertEq(config.owners.length, 3);
        assertEq(config.threshold, 2);
        assertTrue(config.owners[0] != address(0));
        assertTrue(config.owners[1] != address(0));
    }

    // SUBMIT TRANSACTION TESTS

    /**
     * @notice Test that an owner can submit a transaction
     * @dev Verifies that an owner can successfully submit a transaction
     */
    function test_SubmitTransactionByOwner() public {
        // Use the first owner from config
        address owner = config.owners[0];

        vm.prank(owner);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Verify transaction was created
        assertEq(txId, 0);
        assertEq(wallet.getTransactionCount(), 1);

        // Verify transaction details
        MultiSigWallet.Transaction memory transaction = wallet.getTransactions(txId);
        assertEq(transaction.to, recipient);
        assertEq(transaction.value, testValue);
        assertEq(transaction.data, testData);
        assertEq(transaction.description, testDescription);
        assertEq(transaction.executed, false);
        assertEq(transaction.confirmations, 1); // Auto-confirmed by submitter
    }

    /**
     * @notice Test that submitTransaction emits SubmitTransaction event
     * @dev Verifies that the SubmitTransaction event is emitted with correct parameters
     */
    function test_SubmitTransactionEmitsEvent() public {
        address owner = config.owners[0];

        vm.expectEmit(true, true, true, true);
        emit MultiSigWallet.SubmitTransaction(0, owner, recipient, testValue, testData, testDescription);

        vm.prank(owner);
        wallet.submitTransaction(recipient, testValue, testData, testDescription);
    }

    /**
     * @notice Test that submitTransaction auto-confirms by the submitter
     * @dev Verifies that the transaction submitter automatically confirms the transaction
     */
    function test_SubmitTransactionAutoConfirms() public {
        address owner = config.owners[0];

        vm.prank(owner);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Verify the submitter has confirmed
        assertTrue(wallet.getIsConfirmed(txId, owner));
        assertEq(wallet.getTransactions(txId).confirmations, 1);
    }

    /**
     * @notice Test that non-owner cannot submit a transaction
     * @dev Verifies that a non-owner cannot submit a transaction
     */
    function test_SubmitTransactionRevertsWhenNotOwner() public {
        vm.expectRevert(MultiSigWallet.MultiSigWallet__CallerNotAOwner.selector);
        vm.prank(nonOwner);
        wallet.submitTransaction(recipient, testValue, testData, testDescription);
    }

    /**
     * @notice Test that submitTransaction reverts when target is zero address
     * @dev Verifies that submitting a transaction to address(0) reverts
     */
    function test_SubmitTransactionRevertsWhenZeroAddress() public {
        address owner = config.owners[0];

        vm.expectRevert(MultiSigWallet.MultiSigWallet__InvalidTargetAddress.selector);
        vm.prank(owner);
        wallet.submitTransaction(address(0), testValue, testData, testDescription);
    }

    // CONFIRM TRANSACTION TESTS

    /**
     * @notice Test that an owner can confirm a transaction
     * @dev Verifies that an owner can successfully confirm a transaction
     */
    function test_ConfirmTransactionByOwner() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm the transaction
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Verify confirmation was recorded
        assertTrue(wallet.getIsConfirmed(txId, confirmer));
        assertEq(wallet.getTransactions(txId).confirmations, 2); // Submitter + confirmer
    }

    /**
     * @notice Test that confirmTransaction emits ConfirmTransaction event
     * @dev Verifies that the ConfirmTransaction event is emitted with correct parameters
     */
    function test_ConfirmTransactionEmitsEvent() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Expect the event
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.ConfirmTransaction(txId, confirmer);

        // Confirm the transaction
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);
    }

    /**
     * @notice Test that non-owner cannot confirm a transaction
     * @dev Verifies that a non-owner cannot confirm a transaction
     */
    function test_ConfirmTransactionRevertsWhenNotOwner() public {
        address submitter = config.owners[0];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Try to confirm as non-owner
        vm.expectRevert(MultiSigWallet.MultiSigWallet__CallerNotAOwner.selector);
        vm.prank(nonOwner);
        wallet.confirmTransaction(txId);
    }

    /**
     * @notice Test that confirmTransaction reverts for non-existent transaction
     * @dev Verifies that confirming a non-existent transaction reverts
     */
    function test_ConfirmTransactionRevertsWhenTransactionDoesNotExist() public {
        address confirmer = config.owners[0];

        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionDoesNotExist.selector);
        vm.prank(confirmer);
        wallet.confirmTransaction(999); // Non-existent transaction ID
    }

    /**
     * @notice Test that confirmTransaction reverts when already confirmed by same owner
     * @dev Verifies that confirming the same transaction twice by the same owner reverts
     */
    function test_ConfirmTransactionRevertsWhenAlreadyConfirmed() public {
        address owner = config.owners[0];

        // Submit and confirm a transaction
        vm.prank(owner);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Try to confirm again
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionAlreadyConfirmedByThisOwner.selector);
        vm.prank(owner);
        wallet.confirmTransaction(txId);
    }

    /**
     * @notice Test that confirmTransaction reverts when transaction is already executed
     * @dev Verifies that confirming an executed transaction reverts
     */
    function test_ConfirmTransactionRevertsWhenAlreadyExecuted() public fundWallet {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm by enough owners to meet threshold
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Execute the transaction (simulate execution by directly modifying state)
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Try to confirm after execution
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionAlreadyExecuted.selector);
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);
    }

    // EDGE CASES
    /**
     * @notice Test that multiple transactions can be submitted and confirmed
     * @dev Verifies that the wallet handles multiple transactions correctly
     */
    function test_MultipleTransactions() public {
        address owner1 = config.owners[0];
        address owner2 = config.owners[1];

        // Submit multiple transactions
        vm.startPrank(owner1);
        uint256 txId1 = wallet.submitTransaction(recipient, testValue, testData, "Transaction 1");
        uint256 txId2 = wallet.submitTransaction(recipient, testValue, testData, "Transaction 2");
        vm.stopPrank();

        // Confirm both transactions
        vm.prank(owner2);
        wallet.confirmTransaction(txId1);

        vm.prank(owner2);
        wallet.confirmTransaction(txId2);

        // Verify both transactions exist and have correct confirmation counts
        assertEq(wallet.getTransactionCount(), 2);
        assertEq(wallet.getTransactions(txId1).confirmations, 2);
        assertEq(wallet.getTransactions(txId2).confirmations, 2);
    }

    /**
     * @notice Test that transaction confirmations are tracked per owner
     * @dev Verifies that the wallet correctly tracks which owners have confirmed which transactions
     */
    function test_ConfirmationTracking() public {
        address owner1 = config.owners[0];
        address owner2 = config.owners[1];
        address owner3 = config.owners[2];

        // Submit a transaction
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm by different owners
        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.prank(owner3);
        wallet.confirmTransaction(txId);

        // Verify confirmation tracking
        assertTrue(wallet.getIsConfirmed(txId, owner1)); // Auto-confirmed
        assertTrue(wallet.getIsConfirmed(txId, owner2));
        assertTrue(wallet.getIsConfirmed(txId, owner3));
        assertFalse(wallet.getIsConfirmed(txId, nonOwner));

        // Verify total confirmation count
        assertEq(wallet.getTransactions(txId).confirmations, 3);
    }

    // EXECUTE TRANSACTION TESTS

    /**
     * @notice Test that an owner can execute a transaction with enough confirmations
     * @dev Verifies that an owner can successfully execute a transaction with sufficient confirmations
     */
    function test_ExecuteTransactionWithEnoughConfirmations() public fundWallet {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm by enough owners to meet threshold
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Execute the transaction
        uint256 initialRecipientBalance = recipient.balance;
        uint256 initialWalletBalance = address(wallet).balance;

        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Verify execution
        assertEq(recipient.balance - initialRecipientBalance, testValue);
        assertEq(initialWalletBalance - address(wallet).balance, testValue);
        assertTrue(wallet.getTransactions(txId).executed);
    }

    /**
     * @notice Test that executeTransaction emits events correctly
     * @dev Verifies that ExecuteTransaction and ExecuteTransactionSuccess events are emitted
     */
    function test_ExecuteTransactionEmitsEvents() public fundWallet {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm by enough owners to meet threshold
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Expect events
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.ExecuteTransactionSuccess(txId, executor);

        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.ExecuteTransaction(txId, executor);

        // Execute the transaction
        vm.prank(executor);
        wallet.executeTransaction(txId);
    }

    /**
     * @notice Test that executeTransaction reverts without enough confirmations
     * @dev Verifies that executing a transaction without sufficient confirmations reverts
     */
    function test_ExecuteTransactionRevertsWithoutEnoughConfirmations() public {
        address submitter = config.owners[0];
        address executor = config.owners[1];

        // Submit a transaction (only auto-confirmed by submitter)
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Try to execute without enough confirmations
        vm.expectRevert(MultiSigWallet.MultiSigWallet__CannotExecuteTransactionWithoutEnoughConfirmations.selector);
        vm.prank(executor);
        wallet.executeTransaction(txId);
    }

    /**
     * @notice Test that non-owner cannot execute a transaction
     * @dev Verifies that a non-owner cannot execute a transaction
     */
    function test_ExecuteTransactionRevertsWhenNotOwner() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm by enough owners to meet threshold
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Try to execute as non-owner
        vm.expectRevert(MultiSigWallet.MultiSigWallet__CallerNotAOwner.selector);
        vm.prank(nonOwner);
        wallet.executeTransaction(txId);
    }

    /**
     * @notice Test that executeTransaction reverts for non-existent transaction
     * @dev Verifies that executing a non-existent transaction reverts
     */
    function test_ExecuteTransactionRevertsWhenTransactionDoesNotExist() public {
        address executor = config.owners[0];

        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionDoesNotExist.selector);
        vm.prank(executor);
        wallet.executeTransaction(999); // Non-existent transaction ID
    }

    /**
     * @notice Test that executeTransaction reverts when already executed
     * @dev Verifies that executing an already executed transaction reverts
     */
    function test_ExecuteTransactionRevertsWhenAlreadyExecuted() public fundWallet {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm by enough owners to meet threshold
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Execute the transaction
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Try to execute again
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionAlreadyExecuted.selector);
        vm.prank(executor);
        wallet.executeTransaction(txId);
    }

    /**
     * @notice Test that executeTransaction reverts when external call fails
     * @dev Verifies that executing a transaction with a failing external call reverts
     */
    function test_ExecuteTransactionRevertsWhenExternalCallFails() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Create a contract that will revert when called
        RevertingContract revertingContract = new RevertingContract();

        // Submit a transaction to the reverting contract
        vm.prank(submitter);
        uint256 txId =
            wallet.submitTransaction(address(revertingContract), testValue, hex"1234", "Call to reverting contract");

        // Confirm by enough owners to meet threshold
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Try to execute (should revert)
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionExecutionFailed.selector);
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Verify transaction was not marked as executed
        assertFalse(wallet.getTransactions(txId).executed);
    }

    /**
     * @notice Test that executeTransaction increments execution nonce
     * @dev Verifies that the execution nonce is incremented for the executor
     */
    function test_ExecuteTransactionIncrementsExecutionNonce() public fundWallet {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm by enough owners to meet threshold
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Check initial nonce
        uint256 initialNonce = wallet.getExecutionNonce(executor);

        // Execute the transaction
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Verify nonce was incremented
        assertEq(wallet.getExecutionNonce(executor), initialNonce + 1);
    }

    /**
     * @notice Test that an owner can revoke their confirmation
     * @dev Verifies that an owner can successfully revoke their confirmation
     */
    function test_RevokeConfirmationByOwner() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];

        // Submit and confirm a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Verify confirmation exists
        assertTrue(wallet.getIsConfirmed(txId, confirmer));
        assertEq(wallet.getTransactions(txId).confirmations, 2);

        // Revoke the confirmation
        vm.prank(confirmer);
        wallet.revokeConfirmation(txId);

        // Verify revocation
        assertFalse(wallet.getIsConfirmed(txId, confirmer));
        assertEq(wallet.getTransactions(txId).confirmations, 1);
    }

    /**
     * @notice Test that revokeConfirmation emits RevokeConfirmation event
     * @dev Verifies that the RevokeConfirmation event is emitted with correct parameters
     */
    function test_RevokeConfirmationEmitsEvent() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];

        // Submit and confirm a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Expect the event
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.RevokeConfirmation(txId, confirmer);

        // Revoke the confirmation
        vm.prank(confirmer);
        wallet.revokeConfirmation(txId);
    }

    /**
     * @notice Test that non-owner cannot revoke a confirmation
     * @dev Verifies that a non-owner cannot revoke a confirmation
     */
    function test_RevokeConfirmationRevertsWhenNotOwner() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];

        // Submit and confirm a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Try to revoke as non-owner
        vm.expectRevert(MultiSigWallet.MultiSigWallet__CallerNotAOwner.selector);
        vm.prank(nonOwner);
        wallet.revokeConfirmation(txId);
    }

    /**
     * @notice Test that revokeConfirmation reverts when transaction not confirmed
     * @dev Verifies that revoking a non-confirmed transaction reverts
     */
    function test_RevokeConfirmationRevertsWhenNotConfirmed() public {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];

        // Submit a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Try to revoke without confirming first
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionNotConfirmed.selector);
        vm.prank(confirmer);
        wallet.revokeConfirmation(txId);
    }

    /**
     * @notice Test that revokeConfirmation reverts when transaction is executed
     * @dev Verifies that revoking confirmation for an executed transaction reverts
     */
    function test_RevokeConfirmationRevertsWhenExecuted() public fundWallet {
        address submitter = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit and confirm a transaction
        vm.prank(submitter);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Execute the transaction
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Try to revoke after execution
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionAlreadyExecuted.selector);
        vm.prank(confirmer);
        wallet.revokeConfirmation(txId);
    }
}
