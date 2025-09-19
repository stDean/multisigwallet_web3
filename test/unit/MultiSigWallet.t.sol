// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployMultiSigWallet, HelperConfig} from "script/DeployMultiSigWallet.s.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

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

    /**
     * @notice Set up the test environment before each test
     * @dev Deploys the MultiSigWallet contract and retrieves its configuration
     */
    function setUp() external {
        deployer = new DeployMultiSigWallet();
        (wallet, helperConfig) = deployer.run();
        config = helperConfig.getConfig();
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
}