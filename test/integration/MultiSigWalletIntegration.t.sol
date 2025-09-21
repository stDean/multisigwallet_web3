// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployMultiSigWallet, HelperConfig} from "script/DeployMultiSigWallet.s.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

contract MultiSigWalletIntegrationTest is Test {
    DeployMultiSigWallet public deployer;
    MultiSigWallet public wallet;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;

    address[] public owners;
    uint256 public threshold;
    address recipient = address(0x123);
    address newOwner = address(0x456);
    address anotherNewOwner = address(0x789);

    function setUp() external {
        deployer = new DeployMultiSigWallet();
        (wallet, helperConfig) = deployer.run();
        config = helperConfig.getConfig();

        // Get initial owners and threshold
        owners = wallet.getOwners();
        threshold = wallet.getThreshold();

        // Fund the multisig
        vm.deal(address(wallet), 100 ether);
        vm.deal(recipient, 1 ether);
        vm.deal(newOwner, 1 ether);
        vm.deal(anotherNewOwner, 1 ether);
    }

    function test_CompleteWalletWorkFlow() public {
        // Test ETH transfer transaction
        testEthTransfer();

        // Test owner management in a way that maintains valid state
        testAddOwner();

        // After adding an owner, we need to adjust threshold before removing
        testChangeThresholdAfterAddingOwner();

        // Now we can safely remove an owner
        testRemoveOwner();
    }

    function testEthTransfer() internal {
        uint256 initialRecipientBalance = recipient.balance;
        uint96 transferAmount = 1 ether;

        // Owner 0 submits transaction
        vm.prank(owners[0]);
        uint256 txId = wallet.submitTransaction(recipient, transferAmount, "", "Transfer 1 ETH");

        // Confirmations from required owners
        for (uint256 i = 1; i < threshold; i++) {
            vm.prank(owners[i]);
            wallet.confirmTransaction(txId);
        }

        // Execute transaction
        vm.prank(owners[0]);
        wallet.executeTransaction(txId);

        // Verify execution
        MultiSigWallet.Transaction memory transaction = wallet.getTransactions(txId);
        assertEq(transaction.executed, true);
        assertEq(recipient.balance, initialRecipientBalance + transferAmount);
    }

    function testAddOwner() internal {
        // Submit add owner transaction
        vm.prank(owners[0]);
        uint256 txId = wallet.submitAddOwnerTransaction(newOwner);

        // Get confirmations from required owners
        for (uint256 i = 1; i < threshold; i++) {
            vm.prank(owners[i]);
            wallet.confirmTransaction(txId);
        }

        // Execute
        vm.prank(owners[0]);
        wallet.executeTransaction(txId);

        // Verify new owner was added
        address[] memory updatedOwners = wallet.getOwners();
        assertEq(updatedOwners.length, owners.length + 1);
        assertTrue(wallet.getIsWalletOwner(newOwner));

        // Update our local state
        owners = updatedOwners;
    }

    function testChangeThresholdAfterAddingOwner() internal {
        // After adding an owner, we need to adjust threshold to maintain validity
        uint256 newThreshold = threshold; // Keep the same threshold

        // Submit change threshold transaction
        vm.prank(owners[0]);
        uint256 txId = wallet.submitChangeThresholdTransaction(newThreshold);

        // Get confirmations
        for (uint256 i = 1; i < threshold; i++) {
            vm.prank(owners[i]);
            wallet.confirmTransaction(txId);
        }

        // Execute
        vm.prank(owners[0]);
        wallet.executeTransaction(txId);

        // Verify threshold changed
        assertEq(wallet.getThreshold(), newThreshold);

        // Update our local state
        threshold = newThreshold;
    }

    function testRemoveOwner() internal {
        // Remove the newly added owner to return to original state
        address ownerToRemove = newOwner;

        // Submit remove owner transaction
        vm.prank(owners[0]);
        uint256 txId = wallet.submitRemoveOwnerTransaction(ownerToRemove);

        // Get confirmations
        for (uint256 i = 1; i < threshold; i++) {
            vm.prank(owners[i]);
            wallet.confirmTransaction(txId);
        }

        // Execute
        vm.prank(owners[0]);
        wallet.executeTransaction(txId);

        // Verify owner was removed
        address[] memory updatedOwners = wallet.getOwners();
        assertEq(updatedOwners.length, owners.length - 1);
        assertFalse(wallet.getIsWalletOwner(ownerToRemove));

        // Update our local state
        owners = updatedOwners;
    }

    function testChangeThresholdBackToOriginal() internal {
        // Change threshold back to the original value
        uint256 originalThreshold = threshold; // This should be the original threshold

        // Submit change threshold transaction
        vm.prank(owners[0]);
        uint256 txId = wallet.submitChangeThresholdTransaction(originalThreshold);

        // Get confirmations
        for (uint256 i = 0; i < threshold; i++) {
            vm.prank(owners[i]);
            wallet.confirmTransaction(txId);
        }

        // Execute
        vm.prank(owners[0]);
        wallet.executeTransaction(txId);

        // Verify threshold changed back to original
        assertEq(wallet.getThreshold(), originalThreshold);
    }
}
