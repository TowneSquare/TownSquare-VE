// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Constants
/// @notice Single source of truth for protocol-wide constants.
///         To change the epoch duration, update EPOCH here — all contracts
///         that import this library will automatically use the new value.
library Constants {
    /// @notice Duration of one epoch in seconds (2 weeks)
    uint256 internal constant EPOCH = 14 days;
}
