// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployMultiSigWallet, HelperConfig} from "script/DeployMultiSigWallet.s.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

contract MultiSigWalletOpenInvariants is StdInvariant, Test {
    DeployMultiSigWallet public deployer;
    MultiSigWallet public wallet;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;

    address nonOwner = makeAddr("nonOwner");
    address recipient = makeAddr("recipient");
    uint96 testValue = 1 ether;
    bytes testData = hex"1234";
    string testDescription = "Test transaction";

    function setUp() external {
        deployer = new DeployMultiSigWallet();
        (wallet, helperConfig) = deployer.run();
        config = helperConfig.getConfig();

        // Fund the multisig
        vm.deal(address(wallet), 10 ether);
    }

    // Test: Transaction lifecycle should work correctly
    function test_TransactionLifecycle() public {
        address owner = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit transaction
        vm.prank(owner);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm transaction
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Execute transaction
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Verify transaction was executed
        MultiSigWallet.Transaction memory transaction = wallet.getTransactions(txId);
        assertTrue(transaction.executed, "Transaction should be executed");
        assertEq(transaction.confirmations, 2, "Transaction should have 2 confirmations");
    }

    // Test: Owner management should work correctly
    function test_OwnerManagement() public {
        address newOwner = makeAddr("newOwner");
        address owner = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];
        // Submit add owner transaction
        vm.prank(owner);
        uint256 txId = wallet.submitAddOwnerTransaction(newOwner);

        // Confirm transaction
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Execute transaction
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Verify new owner was added
        assertTrue(wallet.getIsWalletOwner(newOwner), "New owner should be added");
        assertEq(wallet.getOwners().length, 4, "Should have 4 owners");
    }

    // Test: Threshold management should work correctly
    function test_ThresholdManagement() public {
        uint256 newThreshold = 3;
        address owner = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit change threshold transaction
        vm.prank(owner);
        uint256 txId = wallet.submitChangeThresholdTransaction(newThreshold);

        // Confirm transaction
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Execute transaction
        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Verify threshold was changed
        assertEq(wallet.getThreshold(), newThreshold, "Threshold should be updated");
    }

    // Test: Revoking confirmation should work correctly
    function test_RevokeConfirmation() public {
        address owner = config.owners[0];
        address confirmer = config.owners[1];

        // Submit transaction
        vm.prank(owner);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        // Confirm transaction
        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        // Revoke confirmation
        vm.prank(confirmer);
        wallet.revokeConfirmation(txId);

        // Verify confirmation was revoked
        assertFalse(wallet.getIsConfirmed(txId, confirmer), "Confirmation should be revoked");
        MultiSigWallet.Transaction memory transaction = wallet.getTransactions(txId);
        assertEq(transaction.confirmations, 1, "Transaction should have 1 confirmation");
    }

    // Test: ETH balance should be properly managed
    function test_EthBalanceManagement() public {
        uint256 initialBalance = address(wallet).balance;
        address owner = config.owners[0];
        address confirmer = config.owners[1];
        address executor = config.owners[2];

        // Submit and execute transaction
        vm.prank(owner);
        uint256 txId = wallet.submitTransaction(recipient, testValue, testData, testDescription);

        vm.prank(confirmer);
        wallet.confirmTransaction(txId);

        vm.prank(executor);
        wallet.executeTransaction(txId);

        // Verify ETH was transferred
        assertEq(address(wallet).balance, initialBalance - testValue, "ETH should be transferred");
        assertEq(recipient.balance, testValue, "Recipient should receive ETH");
    }
}
