// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVotingRewardsFactory {
    /// @notice creates an IncentiveVotingReward contract for a gauge
    /// @param _forwarder            Address of trusted forwarder
    /// @param _rewards             Addresses of pool tokens to be used as valid rewards tokens
    /// @return incentiveVotingReward   Address of IncentiveVotingReward contract created
    function createRewards(address _forwarder, address[] memory _rewards)
        external
        returns (address incentiveVotingReward);
}
