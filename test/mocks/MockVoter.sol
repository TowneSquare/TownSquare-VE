// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";

interface ITownSqGauge {
    function setMerkleRoot(bytes32 _root) external;
    function notifyRewardAmount(uint256 _amount) external;
}

/// @notice Mock Voter for testing TownSqGauge. Holds reward tokens and drives
///         both setMerkleRoot and notifyRewardAmount as the authorised voter.
contract MockVoter is Ownable2Step {
    using SafeERC20 for IERC20;

    address public immutable rewardToken;

    constructor(address _rewardToken) Ownable(msg.sender) {
        rewardToken = _rewardToken;
    }

    /// @notice Set the merkle root on a TownSqGauge.
    function setMerkleRoot(address _gauge, bytes32 _root) external onlyOwner {
        ITownSqGauge(_gauge).setMerkleRoot(_root);
    }

    /// @notice Transfer `_amount` reward tokens from the caller into this contract,
    ///         approve the gauge to pull them, then trigger notifyRewardAmount.
    function notifyRewardAmount(address _gauge, uint256 _amount) external {
        IERC20(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        IERC20(rewardToken).forceApprove(_gauge, _amount);
        ITownSqGauge(_gauge).notifyRewardAmount(_amount);
    }
}
