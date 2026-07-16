// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILoanController} from "../../src/interfaces/ILoanController.sol";

/// @notice Minimal ILoanController stand-in for exercising PoolFactory in tests.
contract MockLoanController is ILoanController {
    mapping(uint8 => bool) public added;
    mapping(uint8 => address) public pools;

    function addPool(uint8 poolId, address pool) external {
        added[poolId] = true;
        pools[poolId] = pool;
    }

    function getUserLoan(
        bytes32
    )
        external
        pure
        returns (
            bytes32 accountId,
            uint16 loanTypeId,
            uint8[] memory colPools,
            uint8[] memory borPools,
            UserLoanCollateral[] memory collateral,
            UserLoanBorrow[] memory borrow
        )
    {
        return (
            bytes32(0),
            0,
            new uint8[](0),
            new uint8[](0),
            new UserLoanCollateral[](0),
            new UserLoanBorrow[](0)
        );
    }

    function isPoolAdded(uint8 poolId) external view returns (bool) {
        return added[poolId];
    }

    function getPool(uint8 poolId) external view returns (address) {
        return pools[poolId];
    }
}
