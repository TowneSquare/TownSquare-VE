// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal stand-in for Minter — Voter only ever calls updatePeriod().
contract MockMinter {
    function updatePeriod() external view returns (uint256) {
        return block.timestamp;
    }
}
