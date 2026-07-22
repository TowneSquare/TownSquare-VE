// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VeArtProxy} from "../src/VeArtProxy.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";

/// @notice Deploys a fresh VeArtProxy and wires it to the existing VotingEscrow.
///
/// Required env vars:
///   PRIVATE_KEY  deployer key (must be team on VotingEscrow)
///
/// Hardcoded:
///   VE  existing VotingEscrow address
contract DeployVeArtProxy is Script {
    address constant VE = 0xa02D0FaD0F143e23B2C63fED93FC79ADf79C4F4d; // replace with deployed VE

    function run() public returns (address artProxy) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_TWO");

        vm.startBroadcast(deployerKey);

        VeArtProxy proxy = new VeArtProxy(VE);
        VotingEscrow(VE).setArtProxy(address(proxy));

        vm.stopBroadcast();

        artProxy = address(proxy);
        console.log("VeArtProxy deployed at:", artProxy);
        console.log("VotingEscrow.artProxy  updated to:", artProxy);
    }
}


// PRIVATE_KEY=0x... forge script script/DeployVeArtProxy.s.sol \
//   --rpc-url <your_rpc> \
//   --broadcast
