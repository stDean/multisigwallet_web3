// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";

/**
 * @title HelperConfig
 * @dev Configuration helper for multi-signature wallet deployment
 * @notice Provides network-specific configuration for deploying MultiSigWallet contracts
 */
contract HelperConfig is Script {
    /// @notice Sepolia testnet chain ID
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;

    /// @notice Local development chain ID (Anvil)
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    struct NetworkConfig {
        address[] owners;
        uint256 threshold;
    }

    /// @notice Active network configuration (primarily for local development)
    NetworkConfig private activeNetworkConfig;

    /// @dev Chain ID to NetworkConfig mapping
    mapping(uint256 => NetworkConfig) private networkConfigs;

    // ERROR
    error HelperConfig__InvalidChainId();

    /**
     * @dev Constructor sets up the active network configuration based on the current chain ID
     */
    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /**
     * @notice Get the current network configuration
     * @return NetworkConfig Current network configuration
     */
    function getConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    /**
     * @notice Get Sepolia network configuration
     * @dev Returns predefined owners and threshold for Sepolia testnet
     * @return NetworkConfig Sepolia network configuration
     */
    function getSepoliaNetworkConfig() internal pure returns (NetworkConfig memory) {
        address[] memory owners = new address[](3);
        owners[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        owners[1] = 0x17d4351aE801b0619ef914756A0423A83f10Af60;
        owners[2] = 0xD949A648cc5a2eFa98f9369ACa2FE6e74D79e02E;

        return NetworkConfig({owners: owners, threshold: 2});
    }

    /**
     * @notice Get or create Anvil network configuration
     * @dev Returns predefined owners and threshold for local Anvil development
     * @return NetworkConfig Anvil network configuration
     */
    function getOrCreateAnvilNetworkConfig() internal returns (NetworkConfig memory) {
        address[] memory owners = new address[](3);
        owners[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        owners[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        owners[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

        activeNetworkConfig = NetworkConfig({owners: owners, threshold: 2});

        return activeNetworkConfig;
    }
}
