// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

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
    error MultiSigWallet__OwnersRequired();
    error MultiSigWallet__InvalidThreshold();
    error MultiSigWallet__InvalidOwner();
    error MultiSigWallet__OwnerNotUnique();

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

    function getOwners() external view returns (address[] memory) {
        return s_owners;
    }

    function getThreshold() external view returns (uint256) {
        return i_threshold;
    }

    function isWalletOwner(address _owner) external view returns (bool) {
        return s_isOwner[_owner];
    }
}
