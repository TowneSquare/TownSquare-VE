// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPoolFactory {
    event SetFeeManager(address indexed feeManager);
    event SetPauser(address indexed pauser);
    event SetPauseState(bool indexed state);
    event SetPoolAdmin(address indexed poolAdmin);

    error NotFeeManager();
    error NotPauser();
    error NotPoolAdmin();
    error ZeroAddress();

    /// @notice Return a single pool created by this factory
    function allPools(uint256 index) external view returns (address);

    /// @notice Returns all pools created by this factory
    function allPools() external view returns (address[] memory);

    /// @notice Returns the number of pools created from this factory
    function allPoolsLength() external view returns (uint256);

    /// @notice Returns true if the address is a pool created by this factory
    function isPool(address pool) external view returns (bool);

    /// @notice Return address of pool for a given token and pool ID
    function getPool(address token, uint8 poolId) external view returns (address);

    /// @notice Set pool administrator
    function setPoolAdmin(address _poolAdmin) external;

    /// @notice Set the pauser for the factory contract
    function setPauser(address _pauser) external;

    /// @notice Pause or unpause pools associated with the factory
    function setPauseState(bool _state) external;

    /// @notice Set the fee manager for the factory contract
    function setFeeManager(address _feeManager) external;

    /// @notice Register a pool for a given token and pool ID
    function createPool(address pool, address token, uint8 poolId) external returns (address);

    /// @notice The pool implementation used to create pools
    function implementation() external view returns (address);

    /// @notice Whether the pools associated with the factory are paused
    function isPaused() external view returns (bool);

    /// @notice The address of the pauser
    function pauser() external view returns (address);

    /// @notice Maximum possible fee
    function MAX_FEE() external view returns (uint256);

    /// @notice Indicator for a zero custom fee override
    function ZERO_FEE_INDICATOR() external view returns (uint256);

    /// @notice Address of the fee manager
    function feeManager() external view returns (address);

    /// @notice Address of the pool administrator
    function poolAdmin() external view returns (address);
}
