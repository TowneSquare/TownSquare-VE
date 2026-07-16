// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VeloGauge} from "../src/gauges/VeloGuage.sol";
import {MockVoter} from "../test/mocks/MockVoter.sol";

contract DeployVeloGauge is Script {
    address rewardToken = vm.envAddress("REWARD_TOKEN");

    address stakingToken = vm.envAddress("STAKING_TOKEN");

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        MockVoter mockVoter = MockVoter(
            0x04D2a0E0b072FD6483bfAb8347B59ccF817Bc836
        );

        VeloGauge gauge = new VeloGauge(
            rewardToken,
            address(mockVoter),
            stakingToken
        );

        vm.stopBroadcast();

        console.log("VeloGauge    deployed at:", address(gauge));
        console.log("  rewardToken :", rewardToken);
        console.log("  voter       :", address(mockVoter));
        console.log("  stakingToken:", stakingToken);
    }
}
