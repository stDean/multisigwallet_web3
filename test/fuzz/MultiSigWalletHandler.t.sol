// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

/**
 * @title MultiSigWalletHandler
 * @dev Optimized handler contract for invariant testing of MultiSigWallet
 */
contract MultiSigWalletHandler is Test {
    MultiSigWallet public multisig;
    address[] public initialOwners;
    uint256 public initialThreshold;

    // Track state for invariants
    uint256 public totalTransactions;
    uint256 public maxOwnersCount; // Track maximum owners count
    mapping(uint256 => bool) public executedTransactions;
    mapping(uint256 => uint256) public confirmationCounts;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    // Test addresses (non-owners)
    address[] public testAddresses;
    
    // Track successful actions to reduce unnecessary calls
    uint256 public lastSuccessfulAction;
    uint256 public nonce;

    constructor(MultiSigWallet _multisig, address[] memory _owners, uint256 _threshold) {
        multisig = _multisig;
        initialOwners = _owners;
        initialThreshold = _threshold;
        maxOwnersCount = _owners.length; // Initialize with initial count

        // Generate test addresses (non-owners)
        for (uint256 i = 0; i < 10; i++) {
            address testAddr = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            testAddresses.push(testAddr);
        }
    }

    // Update the maximum owners count
    function updateMaxOwnersCount() internal {
        uint256 currentOwnerCount = multisig.getOwners().length;
        if (currentOwnerCount > maxOwnersCount) {
            maxOwnersCount = currentOwnerCount;
        }
    }

    // Helper function to get a valid owner
    function getValidOwner() internal returns (address) {
        nonce++;
        address[] memory currentOwners = multisig.getOwners();
        if (currentOwners.length == 0) return address(0);
        
        uint256 index = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, nonce))) % currentOwners.length;
        return currentOwners[index];
    }

    // Helper function to get a random test address (non-owner)
    function getRandomTestAddress() internal returns (address) {
        nonce++;
        uint256 index = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, nonce))) % testAddresses.length;
        return testAddresses[index];
    }

    // Function to submit a transaction
    function submitTransaction() public {
        updateMaxOwnersCount(); // Update max owners count
        address sender = getValidOwner();
        if (sender == address(0)) return;
        
        address to = getRandomTestAddress();
        uint96 value = uint96(uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % 1 ether);
        bytes memory data = abi.encodeWithSignature("dummy()");
        string memory description = "Test transaction";

        vm.prank(sender);
        try multisig.submitTransaction(to, value, data, description) returns (uint256 txId) {
            totalTransactions++;
            confirmationCounts[txId] = 1; // Auto-confirmed by submitter
            confirmations[txId][sender] = true;
            lastSuccessfulAction = block.timestamp;
        } catch {
            // Expected to revert in some cases, no need to handle
        }
    }

    // Function to confirm a transaction
    function confirmTransaction() public {
        updateMaxOwnersCount(); // Update max owners count
        if (totalTransactions == 0) return;

        nonce++;
        uint256 txId = uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % totalTransactions;
        address sender = getValidOwner();
        if (sender == address(0)) return;

        // Skip if already confirmed or executed
        if (confirmations[txId][sender] || executedTransactions[txId]) return;

        vm.prank(sender);
        try multisig.confirmTransaction(txId) {
            confirmationCounts[txId]++;
            confirmations[txId][sender] = true;
            lastSuccessfulAction = block.timestamp;
        } catch {
            // Expected to revert in some cases, no need to handle
        }
    }

    // Function to execute a transaction
    function executeTransaction() public {
        updateMaxOwnersCount(); // Update max owners count
        if (totalTransactions == 0) return;

        nonce++;
        uint256 txId = uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % totalTransactions;
        address sender = getValidOwner();
        if (sender == address(0)) return;

        // Skip if already executed or not enough confirmations
        if (executedTransactions[txId] || confirmationCounts[txId] < multisig.getThreshold()) return;

        // Fund the multisig if needed
        MultiSigWallet.Transaction memory transaction = multisig.getTransactions(txId);
        if (address(multisig).balance < transaction.value) {
            vm.deal(address(multisig), transaction.value);
        }

        vm.prank(sender);
        try multisig.executeTransaction(txId) {
            executedTransactions[txId] = true;
            lastSuccessfulAction = block.timestamp;
        } catch {
            // Expected to revert in some cases, no need to handle
        }
    }

    // Function to revoke a confirmation
    function revokeConfirmation() public {
        updateMaxOwnersCount(); // Update max owners count
        if (totalTransactions == 0) return;

        nonce++;
        uint256 txId = uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % totalTransactions;
        address sender = getValidOwner();
        if (sender == address(0)) return;

        // Skip if not confirmed or executed
        if (!confirmations[txId][sender] || executedTransactions[txId]) return;

        vm.prank(sender);
        try multisig.revokeConfirmation(txId) {
            confirmationCounts[txId]--;
            confirmations[txId][sender] = false;
            lastSuccessfulAction = block.timestamp;
        } catch {
            // Expected to revert in some cases, no need to handle
        }
    }

    // Function to submit an add owner transaction
    function submitAddOwner() public {
        updateMaxOwnersCount(); // Update max owners count
        address sender = getValidOwner();
        if (sender == address(0)) return;
        
        address newOwner = getRandomTestAddress();

        vm.prank(sender);
        try multisig.submitAddOwnerTransaction(newOwner) returns (uint256 txId) {
            totalTransactions++;
            confirmationCounts[txId] = 1; // Auto-confirmed by submitter
            confirmations[txId][sender] = true;
            lastSuccessfulAction = block.timestamp;
        } catch {
            // Expected to revert in some cases, no need to handle
        }
    }

    // Function to submit a remove owner transaction
    function submitRemoveOwner() public {
        updateMaxOwnersCount(); // Update max owners count
        address sender = getValidOwner();
        if (sender == address(0)) return;
        
        address[] memory currentOwners = multisig.getOwners();
        if (currentOwners.length <= 1) return;

        nonce++;
        address ownerToRemove = currentOwners[uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % currentOwners.length];

        vm.prank(sender);
        try multisig.submitRemoveOwnerTransaction(ownerToRemove) returns (uint256 txId) {
            totalTransactions++;
            confirmationCounts[txId] = 1; // Auto-confirmed by submitter
            confirmations[txId][sender] = true;
            lastSuccessfulAction = block.timestamp;
        } catch {
            // Expected to revert in some cases, no need to handle
        }
    }

    // Function to submit a change threshold transaction
    function submitChangeThreshold() public {
        updateMaxOwnersCount(); // Update max owners count
        address sender = getValidOwner();
        if (sender == address(0)) return;
        
        address[] memory currentOwners = multisig.getOwners();
        if (currentOwners.length == 0) return;

        nonce++;
        uint256 newThreshold = (uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % currentOwners.length) + 1;

        vm.prank(sender);
        try multisig.submitChangeThresholdTransaction(newThreshold) returns (uint256 txId) {
            totalTransactions++;
            confirmationCounts[txId] = 1; // Auto-confirmed by submitter
            confirmations[txId][sender] = true;
            lastSuccessfulAction = block.timestamp;
        } catch {
            // Expected to revert in some cases, no need to handle
        }
    }

    // Function to receive ETH (for testing)
    receive() external payable {}
}