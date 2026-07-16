// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VeloGauge} from "../src/gauges/VeloGuage.sol";
import {MockVoter} from "../test/mocks/MockVoter.sol";

contract TransferScript is Script {
    address rewardToken = vm.envAddress("REWARD_TOKEN");

    address stakingToken = vm.envAddress("STAKING_TOKEN");
    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        // IERC20(stakingToken).approve(
        //     0xeab7cA8ab4071eaA912650f8d2D7Ed4697016736,
        //     1000 ether
        // );
        // IERC20(rewardToken).balanceOf(
        //     0x14900Eebf6cFBc4BCCb3Cc68b6Ca869d90468629
        // );
        // IERC20(rewardToken).transfer(
        //     0xa031f11d7CDF039eeF0e73E47Bd5B487f3659B65,
        //     100000 ether
        // );

        // VeloGauge(0xeab7cA8ab4071eaA912650f8d2D7Ed4697016736).deposit(
        //     1000 ether
        // );

        MockVoter mockVoter = MockVoter(
            0x04D2a0E0b072FD6483bfAb8347B59ccF817Bc836
        );

        IERC20(rewardToken).approve(address(mockVoter), 2000 ether);

        mockVoter.notifyRewardAmount(
            0x2490349b41153EE2E50a41b68c6086b525fE124E,
            1000 ether
        );

        // mockVoter.notifyRewardAmount(
        //     0xeab7cA8ab4071eaA912650f8d2D7Ed4697016736,
        //     1000 ether
        // );

        vm.stopBroadcast();
    }
}
