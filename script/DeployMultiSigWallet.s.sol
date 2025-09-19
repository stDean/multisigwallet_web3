// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

/**
 * @title DeployMultiSigWallet
 * @dev Script for deploying MultiSigWallet contracts to various networks
 * @notice Handles deployment of multi-signature wallet contracts with network-specific configuration
 */
contract DeployMultiSigWallet is Script {
    /**
     * @notice Main deployment function
     * @dev Deploys a MultiSigWallet contract with configuration from HelperConfig
     * @return wallet The deployed MultiSigWallet instance
     */
    function run() external returns (MultiSigWallet, HelperConfig) {
        // Get network configuration
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Start broadcast transaction
        vm.startBroadcast();

        // Deploy the multi-signature wallet
        MultiSigWallet wallet = new MultiSigWallet(config.owners, config.threshold);

        // Stop broadcast
        vm.stopBroadcast();

        return (wallet, helperConfig);
    }
}
