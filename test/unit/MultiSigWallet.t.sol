// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {DeployMultiSigWallet, HelperConfig} from "script/DeployMultiSigWallet.s.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    DeployMultiSigWallet deployer;
    MultiSigWallet wallet;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig public config;

    address nonOwner = makeAddr("nonOwner");

    function setUp() external {
        deployer = new DeployMultiSigWallet();
        (wallet, helperConfig) = deployer.run();

        config = helperConfig.getConfig();
    }

    // CONSTRUCTION TEST
    function test_ConstructorSetsCorrectOwners() public view {
        // Check that owners are set correctly
        address[] memory owners = wallet.getOwners();
        assertEq(owners.length, config.owners.length);
    }

    function test_ConstructorSetsCorrectThreshold() public view {
        // Check that threshold is set correctly
        assertEq(wallet.getThreshold(), config.threshold);
    }

    function test_ConstructorOwnersAreMarkedAsOwners() public view {
        // Check that owner addresses are marked as owners
        for (uint256 i = 0; i < config.owners.length; i++) {
            assertTrue(wallet.isWalletOwner(config.owners[i]));
        }
    }

    function test_ConstructorNonOwnersAreNotMarkedAsOwners() public view {
        // Check that non-owner addresses are not marked as owners
        assertFalse(wallet.isWalletOwner(nonOwner));
    }

    function test_ConstructorRevertsWhenNoOwners() public {
        // Test that constructor reverts with no owners
        address[] memory emptyOwners = new address[](0);

        vm.expectRevert("MultiSigWallet__OwnersRequired()");
        new MultiSigWallet(emptyOwners, 1);
    }

    function test_ConstructorRevertsWhenThresholdZero() public {
        vm.expectRevert("MultiSigWallet__InvalidThreshold()");
        new MultiSigWallet(config.owners, 0);
    }

    function test_ConstructorRevertsWhenThresholdGreaterThanOwners() public {
        vm.expectRevert("MultiSigWallet__InvalidThreshold()");
        new MultiSigWallet(config.owners, type(uint256).max);
    }

    function test_ConstructorRevertsWhenOwnerIsZeroAddress() public {
        // Test that constructor reverts with zero address owner
        address[] memory owners = new address[](2);
        owners[0] = config.owners[0];
        owners[1] = address(0);

        uint256 threshold = 2;

        vm.expectRevert("MultiSigWallet__InvalidOwner()");
        new MultiSigWallet(owners, threshold);
    }

    function test_ConstructorRevertsWhenDuplicateOwners() public {
        // Test that constructor reverts with duplicate owners
        address[] memory owners = new address[](2);
        owners[0] = config.owners[0];
        owners[1] = config.owners[0]; // Duplicate
        uint256 threshold = 2;

        vm.expectRevert("MultiSigWallet__OwnerNotUnique()");
        new MultiSigWallet(owners, threshold);
    }

    function test_DeployerReturnsValidContract() public view {
        // Test that the deployer returns a valid contract
        assertTrue(address(wallet) != address(0));
        assertTrue(address(helperConfig) != address(0));
    }

    function test_HelperConfigReturnsValidConfig() public view {
        // Test that helper config returns valid configuration
        assertEq(config.owners.length, 3);
        assertEq(config.threshold, 2);
        assertTrue(config.owners[0] != address(0));
        assertTrue(config.owners[1] != address(0));
        assertTrue(config.owners[2] != address(0));
    }
}
