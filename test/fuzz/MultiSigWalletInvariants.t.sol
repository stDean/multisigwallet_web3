// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployMultiSigWallet, HelperConfig} from "script/DeployMultiSigWallet.s.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";
import {MultiSigWalletHandler} from "test/fuzz/MultiSigWalletHandler.t.sol";

contract MultiSigWalletInvariants is StdInvariant, Test {
    DeployMultiSigWallet public deployer;
    MultiSigWallet public wallet;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;
    MultiSigWalletHandler handler;

    function setUp() external {
        deployer = new DeployMultiSigWallet();
        (wallet, helperConfig) = deployer.run();
        config = helperConfig.getConfig();

        handler = new MultiSigWalletHandler(wallet, config.owners, config.threshold);

        // Fund the multisig
        vm.deal(address(wallet), 100 ether);

        // Target specific functions to reduce reverts
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = handler.submitTransaction.selector;
        selectors[1] = handler.confirmTransaction.selector;
        selectors[2] = handler.executeTransaction.selector;
        selectors[3] = handler.revokeConfirmation.selector;
        selectors[4] = handler.submitAddOwner.selector;
        selectors[5] = handler.submitRemoveOwner.selector;
        selectors[6] = handler.submitChangeThreshold.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    // Invariant: Confirmations should never exceed maximum number of owners
    function invariant_ConfirmationsNeverExceedOwners() public view {
        for (uint256 i = 0; i < handler.totalTransactions(); i++) {
            assertLe(
                handler.confirmationCounts(i),
                handler.maxOwnersCount(),
                "Confirmations should never exceed the maximum number of owners that ever existed"
            );
        }
    }

    // Invariant: Transactions should only be executed once
    function invariant_TransactionsExecutedOnce() public view {
        for (uint256 i = 0; i < handler.totalTransactions(); i++) {
            if (handler.executedTransactions(i)) {
                // If executed, it should stay executed
                assertTrue(handler.executedTransactions(i), "Executed transactions should stay executed");
            }
        }
    }

    // Invariant: Threshold should always be valid
    function invariant_ThresholdAlwaysValid() public view {
        uint256 currentThreshold = wallet.getThreshold();
        uint256 ownerCount = wallet.getOwners().length;

        assertGe(currentThreshold, 1, "Threshold should be at least 1");
        assertLe(currentThreshold, ownerCount, "Threshold should not exceed owner count");
    }

    // Invariant: Only owners can confirm transactions
    function invariant_OnlyOwnersCanConfirm() public view {
        address[] memory currentOwners = wallet.getOwners();

        for (uint256 i = 0; i < handler.totalTransactions(); i++) {
            for (uint256 j = 0; j < currentOwners.length; j++) {
                if (handler.confirmations(i, currentOwners[j])) {
                    assertTrue(
                        wallet.getIsWalletOwner(currentOwners[j]), "Only owners should be able to confirm transactions"
                    );
                }
            }
        }
    }
}
