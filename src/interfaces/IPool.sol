// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool {
    struct DepositData {
        uint16 optimalUtilisationRatio; // 4 d.p.
        uint256 totalAmount;
        uint256 interestRate; // 18 d.p.
        uint256 interestIndex; // 18 d.p.
    }
    function getDepositData() external view returns (DepositData memory);

    /// @notice Called on pool creation by PoolFactory
    /// @param _token0 Address of token0
    /// @param _token1 Address of token1
    /// @param _stable True if stable, false if volatile
    function initialize(
        address _token0,
        address _token1,
        bool _stable
    ) external;
}
