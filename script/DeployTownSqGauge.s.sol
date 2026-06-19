// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TownSqGauge} from "../src/gauges/TownSqGauge.sol";
import {MockVoter} from "../test/mocks/MockVoter.sol";

contract DeployTownSqGauge is Script {
    // Set before running, or pass via environment variables.
    address rewardToken = vm.envAddress("REWARD_TOKEN");

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // Deploy MockVoter first — it becomes the authorised voter on the gauge.
        MockVoter mockVoter = new MockVoter(rewardToken);

        // Deploy TownSqGauge with MockVoter as the voter address.
        TownSqGauge gauge = new TownSqGauge(rewardToken, address(mockVoter));

        vm.stopBroadcast();

        console.log("MockVoter   deployed at:", address(mockVoter));
        console.log("TownSqGauge deployed at:", address(gauge));
        console.log("  rewardToken:", rewardToken);
    }
}
