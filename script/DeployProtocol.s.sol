// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

import {TokenMinter} from "../src/TownMinter.sol";
import {PoolFactory} from "../src/factories/PoolFactory.sol";
import {GaugeFactory} from "../src/factories/GaugeFactory.sol";
import {VotingRewardsFactory} from "../src/factories/VotingRewardsFactory.sol";
import {ManagedRewardsFactory} from "../src/factories/ManagedRewardsFactory.sol";
import {FactoryRegistry} from "../src/factories/FactoryRegistry.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {Voter} from "../src/Voter.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";
import {Minter} from "../src/Minter.sol";

/// @notice Deploys the full TownSq vote-escrow protocol: token + initial
///         distribution, the factory stack, ve, Voter, rewards distributor,
///         and epoch minter — then wires them together.
///
/// Required env vars:
///   PRIVATE_KEY        deployer key (broadcaster)
///   CCIP_ADMIN         address granted DEFAULT_ADMIN_ROLE on TOWN
///   TEAM               team address for TokenMinter/Minter (onlyTeam gate)
///   LOAN_CONTROLLER    pre-existing ILoanController used by PoolFactory
///   INITIAL_SUPPLY     initial TOWN mint amount (wei, <= 10_000_000_000 ether)
///   INVESTOR_BPS, TEAM_BPS, FOUNDATION_BPS, COMMUNITY_BPS, ECOSYSTEM_BPS,
///     LIQUIDITY_BPS    initial distribution split, must sum to 10_000
///
/// Optional env vars:
///   FORWARDER          ERC-2771 trusted forwarder (default: address(0))
///   EMISSION_AMOUNT    per-epoch emission set on Minter (default: 0)
contract DeployProtocol is Script {
    struct Config {
        address forwarder;
        address ccipAdmin;
        address team;
        address loanController;
        uint256 initialSupply;
        uint256 investorBps;
        uint256 teamBps;
        uint256 foundationBps;
        uint256 communityBps;
        uint256 ecosystemBps;
        uint256 liquidityBps;
        uint256 emissionAmount;
    }

    struct Deployment {
        address tokenMinter;
        address town;
        address poolFactory;
        address gaugeFactory;
        address votingRewardsFactory;
        address managedRewardsFactory;
        address factoryRegistry;
        address ve;
        address voter;
        address rewardsDistributor;
        address minter;
    }

    function run() public returns (Deployment memory d) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        Config memory cfg = Config({
            forwarder: vm.envOr("FORWARDER", address(0)),
            ccipAdmin: vm.envAddress("CCIP_ADMIN"),
            team: vm.envAddress("TEAM"),
            loanController: vm.envAddress("LOAN_CONTROLLER"),
            initialSupply: vm.envUint("INITIAL_SUPPLY"),
            investorBps: vm.envUint("INVESTOR_BPS"),
            teamBps: vm.envUint("TEAM_BPS"),
            foundationBps: vm.envUint("FOUNDATION_BPS"),
            communityBps: vm.envUint("COMMUNITY_BPS"),
            ecosystemBps: vm.envUint("ECOSYSTEM_BPS"),
            liquidityBps: vm.envUint("LIQUIDITY_BPS"),
            emissionAmount: vm.envOr("EMISSION_AMOUNT", uint256(0))
        });

        vm.startBroadcast(deployerKey);
        d = deploy(cfg, deployer);
        vm.stopBroadcast();

        _logDeployment(d, cfg.team, deployer);
    }

    /// @dev Pure deployment logic, kept free of vm.env*/broadcast calls so it
    ///      can be exercised directly (e.g. under vm.prank) in tests without
    ///      going through process-wide environment variables.
    function deploy(
        Config memory cfg,
        address deployer
    ) public returns (Deployment memory d) {
        // 1. Token + initial distribution buckets (deploys TOWN internally)
        TokenMinter tokenMinter = new TokenMinter(
            cfg.initialSupply,
            cfg.ccipAdmin,
            cfg.team,
            cfg.investorBps,
            cfg.teamBps,
            cfg.foundationBps,
            cfg.communityBps,
            cfg.ecosystemBps,
            cfg.liquidityBps
        );
        address town = address(tokenMinter.town());

        // 2. Factory stack
        PoolFactory poolFactory = new PoolFactory(cfg.loanController);
        GaugeFactory gaugeFactory = new GaugeFactory();
        VotingRewardsFactory votingRewardsFactory = new VotingRewardsFactory();
        ManagedRewardsFactory managedRewardsFactory = new ManagedRewardsFactory();
        FactoryRegistry factoryRegistry = new FactoryRegistry(
            address(poolFactory),
            address(votingRewardsFactory),
            address(gaugeFactory),
            address(managedRewardsFactory)
        );

        // 3. Vote-escrow + voting + rebase/emissions
        VotingEscrow ve = new VotingEscrow(
            cfg.forwarder,
            town,
            address(factoryRegistry)
        );
        Voter voter = new Voter(
            cfg.forwarder,
            address(ve),
            address(factoryRegistry)
        );
        RewardsDistributor rewardsDistributor = new RewardsDistributor(
            address(ve)
        );
        Minter minter = new Minter(town, cfg.team);

        // 4. Wiring that only requires deployer authority (deployer is the
        //    initial ve.voter / voter.minter / rewardsDistributor.minter)
        ve.setVoterAndDistributor(address(voter), address(rewardsDistributor));

        address[] memory initialWhitelist = new address[](1);
        initialWhitelist[0] = town;
        voter.initialize(initialWhitelist, address(minter));

        rewardsDistributor.setMinter(address(minter));

        // 5. Wiring gated by `onlyTeam` — only runnable here if TEAM is the
        //    broadcasting deployer. Otherwise the team wallet must send these
        //    afterward (see console output from `run()`).
        if (cfg.team == deployer) {
            minter.setVoter(address(voter));
            minter.setVe(address(ve));
            minter.setRewardsDistributor(address(rewardsDistributor));
            minter.setEmissionAmount(cfg.emissionAmount);
        }

        d = Deployment({
            tokenMinter: address(tokenMinter),
            town: town,
            poolFactory: address(poolFactory),
            gaugeFactory: address(gaugeFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            managedRewardsFactory: address(managedRewardsFactory),
            factoryRegistry: address(factoryRegistry),
            ve: address(ve),
            voter: address(voter),
            rewardsDistributor: address(rewardsDistributor),
            minter: address(minter)
        });
    }

    function _logDeployment(
        Deployment memory d,
        address team,
        address deployer
    ) internal view {
        console.log("TokenMinter          deployed at:", d.tokenMinter);
        console.log("TOWN                 deployed at:", d.town);
        console.log("PoolFactory          deployed at:", d.poolFactory);
        console.log("GaugeFactory         deployed at:", d.gaugeFactory);
        console.log(
            "VotingRewardsFactory deployed at:",
            d.votingRewardsFactory
        );
        console.log(
            "ManagedRewardsFactory deployed at:",
            d.managedRewardsFactory
        );
        console.log("FactoryRegistry      deployed at:", d.factoryRegistry);
        console.log("VotingEscrow         deployed at:", d.ve);
        console.log("Voter                deployed at:", d.voter);
        console.log("RewardsDistributor   deployed at:", d.rewardsDistributor);
        console.log("Minter               deployed at:", d.minter);

        if (team != deployer) {
            console.log(
                "\nTEAM (%s) != deployer -- run these from the team wallet:",
                team
            );
            console.log("  minter.setVoter(%s)", d.voter);
            console.log("  minter.setVe(%s)", d.ve);
            console.log(
                "  minter.setRewardsDistributor(%s)",
                d.rewardsDistributor
            );
            console.log("  minter.setEmissionAmount(<amount>)");
        }

        console.log(
            "\nRemember to fund the Minter with TOWN before the first updatePeriod(), e.g.:"
        );
        console.log(
            "  tokenMinter.distribute(Distribution.ECOSYSTEM, <amount>, %s)",
            d.minter
        );
    }
}
