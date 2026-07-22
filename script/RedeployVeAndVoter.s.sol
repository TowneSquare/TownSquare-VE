// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

import {VotingEscrow} from "../src/VotingEscrow.sol";
import {Voter} from "../src/Voter.sol";
import {VeArtProxy} from "../src/VeArtProxy.sol";
import {Minter} from "../src/Minter.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";

/// @notice Redeploys VotingEscrow, Voter, VeArtProxy, and RewardsDistributor
///         against an existing token + factory stack, then rewires Minter to
///         point at all new contracts.
///
/// NOTE: RewardsDistributor.ve is immutable — the old distributor cannot be
///       reused with a new VotingEscrow, so a fresh one is always deployed.
///
/// Required env vars:
///   PRIVATE_KEY      deployer key (must be team on Minter)
///   FORWARDER        trusted forwarder address (optional, defaults to address(0))
///   WHITELIST_TOKEN  token to whitelist in Voter (optional, defaults to TOWN)
contract RedeployVeAndVoter is Script {
    // ── Existing protocol addresses ──────────────────────────────────────────
    address constant TOWN             = 0xf3b74999EC39959132F20be641fBeb1941B13A22;
    address constant FACTORY_REGISTRY = 0xc96449BF5C35915B0871140C023Ab788c84F676D;
    address constant MINTER           = 0xd0E5FCb608774976699d4A37205AEeEccC9A2b17;

    struct Deployment {
        address ve;
        address voter;
        address artProxy;
        address rewardsDistributor;
    }

    function run() public returns (Deployment memory d) {
        uint256 deployerKey    = vm.envUint("PRIVATE_KEY");
        address forwarder      = vm.envOr("FORWARDER", address(0));
        address whitelistToken = vm.envOr("WHITELIST_TOKEN", TOWN);

        vm.startBroadcast(deployerKey);
        d = _deploy(forwarder, whitelistToken);
        vm.stopBroadcast();

        _log(d);
    }

    function _deploy(
        address forwarder,
        address whitelistToken
    ) internal returns (Deployment memory d) {
        VotingEscrow ve             = new VotingEscrow(forwarder, TOWN, FACTORY_REGISTRY);
        Voter voter                 = new Voter(forwarder, address(ve), FACTORY_REGISTRY);
        VeArtProxy artProxy         = new VeArtProxy(address(ve));
        RewardsDistributor rewardsDist = new RewardsDistributor(address(ve));

        _wireContracts(ve, voter, artProxy, rewardsDist, whitelistToken);

        d = Deployment({
            ve:                 address(ve),
            voter:              address(voter),
            artProxy:           address(artProxy),
            rewardsDistributor: address(rewardsDist)
        });
    }

    function _wireContracts(
        VotingEscrow ve,
        Voter voter,
        VeArtProxy artProxy,
        RewardsDistributor rewardsDist,
        address whitelistToken
    ) internal {
        // Wire VotingEscrow
        ve.setVoterAndDistributor(address(voter), address(rewardsDist));
        ve.setArtProxy(address(artProxy));

        // Wire Voter
        address[] memory whitelist = new address[](1);
        whitelist[0] = whitelistToken;
        voter.initialize(whitelist, MINTER);

        // Wire Minter to new VE, Voter, and RewardsDistributor
        Minter(MINTER).setVe(address(ve));
        Minter(MINTER).setVoter(address(voter));
        Minter(MINTER).setRewardsDistributor(address(rewardsDist));

        // Wire RewardsDistributor minter reference
        rewardsDist.setMinter(MINTER);
    }

    function _log(Deployment memory d) internal view {
        console.log("VotingEscrow       deployed at:", d.ve);
        console.log("Voter              deployed at:", d.voter);
        console.log("VeArtProxy         deployed at:", d.artProxy);
        console.log("RewardsDistributor deployed at:", d.rewardsDistributor);
        console.log("");
        console.log("Minter.ve                  ->", d.ve);
        console.log("Minter.voter               ->", d.voter);
        console.log("Minter.rewardsDistributor  ->", d.rewardsDistributor);
    }
}
