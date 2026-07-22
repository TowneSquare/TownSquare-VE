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
import {VeArtProxy} from "../src/VeArtProxy.sol";

/// @notice Deploys the full TownSq vote-escrow protocol: token + initial
///         distribution, the factory stack, ve, Voter, rewards distributor,
///         and epoch minter — then wires them together.
///
/// Required env vars:
///   PRIVATE_KEY        deployer key (broadcaster)
///   CCIP_ADMIN         address granted DEFAULT_ADMIN_ROLE on TOWN
///   TEAM               team address for TokenMinter/Minter (onlyTeam gate)
///   LOAN_CONTROLLER    pre-existing ILoanController used by PoolFactory
///
/// The initial distribution split (INVESTOR_BPS/TEAM_BPS/FOUNDATION_BPS/
/// COMMUNITY_BPS/ECOSYSTEM_BPS/LIQUIDITY_BPS below) is fixed in-contract
/// rather than configurable per deployment.
///
/// No ERC-2771 trusted forwarder is deployed/wired up yet — Voter and
/// VotingEscrow are both constructed with forwarder = address(0). Revisit
/// if/when meta-tx support is actually needed.
contract DeployProtocol is Script {
    // ── Allocation (must sum to 10_000 bps = 100%) ──────────────────────────
    uint256 constant INVESTOR_BPS = 1800; // 18%
    uint256 constant TEAM_BPS = 1500; // 15%
    uint256 constant FOUNDATION_BPS = 2000; // 20%
    uint256 constant COMMUNITY_BPS = 3700; // 37%
    uint256 constant ECOSYSTEM_BPS = 900; //  9%
    uint256 constant LIQUIDITY_BPS = 100; //  1%
    uint256 constant INITIAL_SUPPLY = 10_000_000_000 ether;

    struct Config {
        address ccipAdmin;
        address team;
        address loanController;
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
        address artProxy;
    }

    function run() public returns (Deployment memory d) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_TWO");
        address deployer = vm.addr(deployerKey);

        Config memory cfg = Config({
            ccipAdmin: vm.envAddress("CCIP_ADMIN"),
            team: vm.envAddress("TEAM"),
            loanController: vm.envAddress("LOAN_CONTROLLER")
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
        TokenMinter tokenMinter;
        address town;
        (
            tokenMinter,
            town
        ) = _deployTokenMinter(cfg);

        PoolFactory poolFactory;
        GaugeFactory gaugeFactory;
        VotingRewardsFactory votingRewardsFactory;
        ManagedRewardsFactory managedRewardsFactory;
        FactoryRegistry factoryRegistry;
        (
            poolFactory,
            gaugeFactory,
            votingRewardsFactory,
            managedRewardsFactory,
            factoryRegistry
        ) = _deployFactoryStack(cfg.loanController);

        VotingEscrow ve;
        Voter voter;
        RewardsDistributor rewardsDistributor;
        Minter minter;
        VeArtProxy artProxy;
        (
            ve,
            voter,
            rewardsDistributor,
            minter,
            artProxy
        ) = _deployVeStack(town, address(factoryRegistry), cfg.team);

        _configureDeployment(
            ve,
            voter,
            rewardsDistributor,
            minter,
            artProxy,
            town,
           10000 ether,
            cfg.team,
            deployer
        );

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
            minter: address(minter),
            artProxy: address(artProxy)
        });
    }

    function _deployTokenMinter(
        Config memory cfg
    ) internal returns (TokenMinter tokenMinter, address town) {
        tokenMinter = new TokenMinter(
            INITIAL_SUPPLY,
            cfg.ccipAdmin,
            cfg.team,
            INVESTOR_BPS,
            TEAM_BPS,
            FOUNDATION_BPS,
            COMMUNITY_BPS,
            ECOSYSTEM_BPS,
            LIQUIDITY_BPS
        );
        town = address(tokenMinter.town());
    }

    function _deployFactoryStack(
        address loanController
    )
        internal
        returns (
            PoolFactory poolFactory,
            GaugeFactory gaugeFactory,
            VotingRewardsFactory votingRewardsFactory,
            ManagedRewardsFactory managedRewardsFactory,
            FactoryRegistry factoryRegistry
        )
    {
        poolFactory = new PoolFactory(loanController);
        gaugeFactory = new GaugeFactory();
        votingRewardsFactory = new VotingRewardsFactory();
        managedRewardsFactory = new ManagedRewardsFactory();
        factoryRegistry = new FactoryRegistry(
            address(poolFactory),
            address(votingRewardsFactory),
            address(gaugeFactory),
            address(managedRewardsFactory)
        );
    }

    function _deployVeStack(
        address town,
        address factoryRegistry,
        address team
    )
        internal
        returns (
            VotingEscrow ve,
            Voter voter,
            RewardsDistributor rewardsDistributor,
            Minter minter,
            VeArtProxy artProxy
        )
    {
        ve = new VotingEscrow(address(0), town, factoryRegistry);
        voter = new Voter(address(0), address(ve), factoryRegistry);
        rewardsDistributor = new RewardsDistributor(address(ve));
        minter = new Minter(town, team);
        artProxy = new VeArtProxy(address(ve));
    }

    function _configureDeployment(
        VotingEscrow ve,
        Voter voter,
        RewardsDistributor rewardsDistributor,
        Minter minter,
        VeArtProxy artProxy,
        address town,
        uint256 emissionAmount,
        address team,
        address deployer
    ) internal {
        ve.setVoterAndDistributor(address(voter), address(rewardsDistributor));
        ve.setArtProxy(address(artProxy));

        address[] memory initialWhitelist = new address[](1);
        initialWhitelist[0] = town;
        voter.initialize(initialWhitelist, address(minter));

        rewardsDistributor.setMinter(address(minter));

        if (team == deployer) {
            minter.setVoter(address(voter));
            minter.setVe(address(ve));
            minter.setRewardsDistributor(address(rewardsDistributor));
            minter.setEmissionAmount(emissionAmount);
        }
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
        console.log("VeArtProxy           deployed at:", d.artProxy);

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


// == Logs ==
//   TokenMinter          deployed at: 0xB1DC7EE9c245d4092553a322e38ecD47C7c70961
//   TOWN                 deployed at: 0xcDa6e58165a3b4596004ED05366E6e2B8dC82b5C
//   PoolFactory          deployed at: 0x96a1F8450473568D2e3DF6d7aa01a535B69Ba9F9
//   GaugeFactory         deployed at: 0xE1D6d8fcd0c4a4f7DEDaDDeFCA377a0DA97c237A
//   VotingRewardsFactory deployed at: 0x6Bf92b5d1a96dBb6BA99fAECF397Eee4a4EbDc3c
//   ManagedRewardsFactory deployed at: 0x691646ac39E8f5048Eb8540D35AA47f7628E322A
//   FactoryRegistry      deployed at: 0x5FfD14714715B9C444217b5b2B1C94fDf12d1502
//   VotingEscrow         deployed at: 0xa02D0FaD0F143e23B2C63fED93FC79ADf79C4F4d
//   Voter                deployed at: 0x59c036b729aA103FCf2d5509152156b9b5F20459
//   RewardsDistributor   deployed at: 0x04A3946B9cf20040162758cEe1d47Cb282630e18
//   Minter               deployed at: 0x8e7a9b09357Fc2F79D3c345db36C90C3fef93714
//   VeArtProxy           deployed at: 0xD30eb97a0373f73714634b9aE099186D5310af9D