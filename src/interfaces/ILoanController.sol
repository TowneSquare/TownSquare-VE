// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILoanController {
    struct UserLoanCollateral {
        uint256 balance; // denominated in ts token
        uint256 rewardIndex;
    }

    struct UserLoanBorrow {
        uint256 amount; // excluding interest
        uint256 balance; // including interest
        uint256 lastInterestIndex;
        uint256 stableInterestRate; // defined if stable borrow
        uint256 lastStableUpdateTimestamp; // defined if stable borrow
        uint256 rewardIndex;
    }

    function getUserLoan(
        bytes32 loanId
    )
        external
        view
        returns (
            bytes32 accountId,
            uint16 loanTypeId,
            uint8[] memory colPools,
            uint8[] memory borPools,
            UserLoanCollateral[] memory,
            UserLoanBorrow[] memory
        );

    function isPoolAdded(uint8 poolId) external view returns (bool);

    function getPool(uint8 poolId) external view returns (address);
}
