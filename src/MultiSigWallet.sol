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

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length >= 1, "MultiSig: owners required");
        require(_threshold >= 1 && _threshold <= _owners.length, "MultiSig: invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "MultiSig: invalid owner");
            require(!s_isOwner[owner], "MultiSig: owner not unique");

            s_isOwner[owner] = true;
            s_owners.push(owner);
        }

        i_threshold = _threshold;
    }
}
