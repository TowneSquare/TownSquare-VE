// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGauge {
    error NotAlive();
    error NotAuthorized();
    error NotVoter();
    error NotTeam();
    error RewardRateTooHigh();
    error ZeroAmount();
    error ZeroRewardRate();
    error MerkleRootNotSet();
    error InvalidProof();
    error InsufficientContractBalance();
    error ZeroRoot();
    error InvalidSplit();

    event NotifyReward(address indexed from, uint256 amount);
    event MerkleRootUpdated(bytes32 root);
    event Claimed(address indexed sender, uint256 amount);
    event RewardSplitUpdated(uint256 collateralBps, uint256 borrowBps);

    /// @notice Merkle root used for reward claim verification
    function root() external view returns (bytes32);

    /// @notice Address of the token (TOWN) rewarded to stakers
    function rewardToken() external view returns (address);

    /// @notice Address of Voter
    function voter() external view returns (address);

    /// @notice Address of the factory that created this gauge
    function gaugeFactory() external view returns (address);

    /// @notice Timestamp end of current rewards period
    function periodFinish() external view returns (uint256);

    /// @notice Current collateral reward rate per second
    function collateralRewardRate() external view returns (uint256);

    /// @notice Current borrow reward rate per second
    function borrowRewardRate() external view returns (uint256);

    /// @notice Most recent timestamp contract has updated state
    function lastUpdateTime() external view returns (uint256);

    /// @notice Most recent stored value of collateral rewardPerToken
    function collateralRewardPerTokenStored() external view returns (uint256);

    /// @notice Most recent stored value of borrow rewardPerToken
    function borrowRewardPerTokenStored() external view returns (uint256);

    /// @notice Total collateral amount tracked by the gauge
    function totalCollateral() external view returns (uint256);

    /// @notice Combined reward rate (collateral + borrow)
    function totalRewardRate() external view returns (uint256);

    /// @notice Basis points allocated to collateral rewards (out of 10000)
    function collateralBps() external view returns (uint256);

    /// @notice Basis points allocated to borrow rewards (out of 10000)
    function borrowBps() external view returns (uint256);

    /// @notice Collateral reward rate per epoch start timestamp
    function collateralRewardRateByEpoch(uint256) external view returns (uint256);

    /// @notice Borrow reward rate per epoch start timestamp
    function borrowRewardRateByEpoch(uint256) external view returns (uint256);

    /// @notice Returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable() external view returns (uint256 _time);

    /// @notice Total amount of rewardToken to distribute for the current rewards period
    function left() external view returns (uint256 _left);

    /// @notice Sets the collateral/borrow reward split. Only callable by voter.
    function setRewardSplit(uint256 _collateralBps, uint256 _borrowBps) external;

    /// @notice Sets the merkle root used to verify reward claims
    function setMerkleRoot(bytes32 _root) external;

    /// @notice Claims rewards for the caller using a merkle proof
    function getReward(uint256 reward, bytes32[] calldata proof) external;

    /// @dev Notifies gauge of gauge rewards.
    function notifyRewardAmount(uint256 amount) external;

    /// @dev Notifies gauge of gauge rewards without distributing fees.
    function notifyRewardWithoutClaim(uint256 amount) external;
}
