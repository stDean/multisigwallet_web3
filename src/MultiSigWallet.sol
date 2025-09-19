// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Multi-signature Wallet
 * @dev A contract that requires multiple approvals for transactions
 * @notice Allows a group of owners to collectively manage funds with enhanced security
 */
contract MultiSigWallet is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // State variables
    address[] private s_owners;
    mapping(address => bool) private s_isOwner;
    uint256 private immutable i_threshold;
    uint256 private s_transactionCount;
    uint256 private s_requiredConfirmations;

    // ERRORS

    /**
     * @dev Error thrown when no owners are provided during initialization
     */
    error MultiSigWallet__OwnersRequired();

    /**
     * @dev Error thrown when an invalid threshold is provided
     * @notice Threshold must be at least 1 and cannot exceed the number of owners
     */
    error MultiSigWallet__InvalidThreshold();

    /**
     * @dev Error thrown when a zero address is provided as an owner
     */
    error MultiSigWallet__InvalidOwner();

    /**
     * @dev Error thrown when duplicate owners are provided
     */
    error MultiSigWallet__OwnerNotUnique();

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

        i_threshold = _threshold;
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
        return i_threshold;
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
}