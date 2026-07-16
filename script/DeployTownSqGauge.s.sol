// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Gauge} from "../src/gauges/Gauge.sol";
import {MockVoter} from "../test/mocks/MockVoter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployGauge is Script {
    // Set before running, or pass via environment variables.
    address rewardToken = vm.envAddress("REWARD_TOKEN");

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // Deploy MockVoter first — it becomes the authorised voter on the gauge.

        MockVoter mockVoter = MockVoter(
            0x04D2a0E0b072FD6483bfAb8347B59ccF817Bc836
        );

        // IERC20(rewardToken).approve(address(mockVoter), 1000 ether);

        // mockVoter.notifyRewardAmount(
        //     0xD7102922c5Cae1BF165f708dB5b056F48A4220DD,
        //     1000 ether
        // );

        // Deploy TownSqGauge with MockVoter as the voter address.
        Gauge gauge = new Gauge(rewardToken, address(mockVoter));

        // gauge.setTotalCollateral(2000 ether);

        // gauge.updateCollateralRewardPerTokenStored();

        IERC20(rewardToken).approve(address(mockVoter), 2000 ether);

        mockVoter.notifyRewardAmount(address(gauge), 1000 ether);

        vm.stopBroadcast();

        console.log("MockVoter   deployed at:", address(mockVoter));
        console.log("TownSqGauge deployed at:", address(gauge));
        console.log("  rewardToken:", rewardToken);
    }
}
