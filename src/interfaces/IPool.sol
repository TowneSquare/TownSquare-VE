// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPool {
    struct DepositData {
        uint16 optimalUtilisationRatio; // 4 d.p.
        uint256 totalAmount;
        uint256 interestRate; // 18 d.p.
        uint256 interestIndex; // 18 d.p.
    }

    struct VariableBorrowData {
        uint32 vr0; // 6 d.p.
        uint32 vr1; // 6 d.p.
        uint32 vr2; // 6 d.p.
        uint256 totalAmount;
        uint256 interestRate; // 18 d.p.
        uint256 interestIndex; // 18 d.p.
    }

    struct StableBorrowData {
        uint32 sr0; // 6 d.p.
        uint32 sr1; // 6 d.p.
        uint32 sr2; // 6 d.p.
        uint32 sr3; // 6 d.p.
        uint16 optimalStableToTotalDebtRatio; // 4 d.p.
        uint16 rebalanceUpUtilisationRatio; // 4 d.p.
        uint16 rebalanceUpDepositInterestRate; // 4 d.p.
        uint16 rebalanceDownDelta; // 4 d.p.
        uint256 totalAmount;
        uint256 interestRate; // 18 d.p.
        uint256 averageInterestRate; // 18 d.p.
    }
    function getDepositData() external view returns (DepositData memory);
    function getVariableBorrowData()
        external
        view
        returns (VariableBorrowData memory);
    function getStableBorrowData()
        external
        view
        returns (StableBorrowData memory);

    /// @notice Called on pool creation by PoolFactory
    /// @param _token0 Address of token0
    /// @param _token1 Address of token1
    /// @param _stable True if stable, false if volatile
    function initialize(
        address _token0,
        address _token1,
        bool _stable
    ) external;

    function getPoolId() external view returns (uint8);
}
