// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPoolFactory {
    /// @notice Returns true if the address is a pool created by this factory
    function isPool(uint8 poolId) external view returns (bool);
    /// @notice The pool implementation used to create pools
    function loanController() external view returns (address);

    function getPool(uint8 poolId) external view returns (address);
}
