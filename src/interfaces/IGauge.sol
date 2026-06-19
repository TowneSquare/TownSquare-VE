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

    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed from, uint256 amount);
    event NotifyReward(address indexed from, uint256 amount);
    event ClaimRewards(address indexed from, uint256 amount);

    /// @notice Address of the pool LP token which is deposited (staked) for rewards
    function stakingToken() external view returns (address);

    /// @notice Address of the token (TOWN) rewarded to stakers
    function rewardToken() external view returns (address);

    /// @notice Address of the FeesVotingReward contract linked to the gauge
    function feesVotingReward() external view returns (address);

    /// @notice Address of Voter
    function voter() external view returns (address);

    /// @notice Address of the factory that created this gauge
    function gaugeFactory() external view returns (address);

    /// @notice Returns if gauge is linked to a legitimate pool
    function isPool() external view returns (bool);

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

    /// @notice Total borrow amount tracked by the gauge
    function totalBorrow() external view returns (uint256);

    /// @notice Combined reward rate (collateral + borrow)
    function totalRewardRate() external view returns (uint256);

    /// @notice Get the amount of stakingToken deposited by an account
    function balanceOf(address) external view returns (uint256);

    /// @notice Cached collateral rewardPerTokenStored for an account
    function userCollateralRewardPerTokenPaid(address) external view returns (uint256);

    /// @notice Cached borrow rewardPerTokenStored for an account
    function userBorrowRewardPerTokenPaid(address) external view returns (uint256);

    /// @notice Cached collateral rewards earned for an account
    function collateralRewards(address) external view returns (uint256);

    /// @notice Cached borrow rewards earned for an account
    function borrowRewards(address) external view returns (uint256);

    /// @notice Collateral reward rate per epoch start timestamp
    function collateralRewardRateByEpoch(uint256) external view returns (uint256);

    /// @notice Borrow reward rate per epoch start timestamp
    function borrowRewardRateByEpoch(uint256) external view returns (uint256);

    /// @notice Cached amount of fees generated from the Pool linked to the Gauge of token0
    function fees0() external view returns (uint256);

    /// @notice Cached amount of fees generated from the Pool linked to the Gauge of token1
    function fees1() external view returns (uint256);

    /// @notice Returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable() external view returns (uint256 _time);

    /// @notice Returns accrued collateral and borrow rewards to date for an account
    function earned(address _account, bytes32[] memory _accountLoans, uint16 _chainId)
        external
        view
        returns (uint256 collateralReward, uint256 borrowReward);

    /// @notice Total amount of rewardToken to distribute for the current rewards period
    function left() external view returns (uint256 _left);

    /// @notice Retrieve rewards for an address.
    function getReward(
        address _account,
        bytes32 _accountId,
        uint16 _chainId,
        bytes32[] memory _accountLoans
    ) external;

    /// @dev Notifies gauge of gauge rewards.
    function notifyRewardAmount(uint256 amount) external;

    /// @dev Notifies gauge of gauge rewards without distributing fees.
    function notifyRewardWithoutClaim(uint256 amount) external;
}
