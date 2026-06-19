// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISinkGauge {
    error NotVoter();
    error ZeroAmount();

    event NotifyReward(address indexed _from, uint256 _amount);
    event ClaimRewards(address indexed _from, uint256 _amount);

    /// @notice Address of the reward token (TOWN)
    function rewardToken() external view returns (address);

    /// @notice Address of the Voter contract
    function voter() external view returns (address);

    /// @notice Address of the Minter contract
    function minter() external view returns (address);

    /// @notice Total rewards received (never decremented)
    function lockedRewards() external view returns (uint256);

    /// @notice Reward amount received per epoch start timestamp
    function tokenRewardsPerEpoch(uint256 _epochStart) external view returns (uint256);

    /// @notice Always returns 0 — no rewards are held by this contract
    function left() external pure returns (uint256);

    /// @notice No-op reward claim — sink gauge does not distribute rewards
    function getReward(address _account) external;

    /// @notice Receives emissions from Voter and forwards them to Minter
    function notifyRewardAmount(uint256 _amount) external;
}
