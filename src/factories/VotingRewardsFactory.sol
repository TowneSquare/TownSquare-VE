// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {
    IVotingRewardsFactory
} from "../interfaces/factories/IVotingRewardsFactory.sol";
//import {FeesVotingReward} from "../rewards/FeesVotingReward.sol";
import {IncentiveVotingReward} from "../rewards/IncentiveVotingReward.sol";

contract VotingRewardsFactory is IVotingRewardsFactory {
    /// @inheritdoc IVotingRewardsFactory
    function createRewards(
        address[] memory _rewards
    ) external returns (address incentiveVotingReward) {
        //feesVotingReward = address(new FeesVotingReward(_forwarder, msg.sender, _rewards));
        incentiveVotingReward = address(
            new IncentiveVotingReward(msg.sender, _rewards)
        );
    }
}
