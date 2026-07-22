// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployProtocol} from "../script/DeployProtocol.s.sol";
import {TokenMinter} from "../src/TownMinter.sol";
import {ITokenMinter} from "../src/interfaces/ITokenMinter.sol";
import {PoolFactory} from "../src/factories/PoolFactory.sol";
import {FactoryRegistry} from "../src/factories/FactoryRegistry.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {Voter} from "../src/Voter.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";
import {Minter} from "../src/Minter.sol";
import {MockLoanController} from "./mocks/MockLoanController.sol";

/// @dev vm.startBroadcast only re-attributes creates/calls made directly by
///      the contract that invoked it. deploy() relies on ambient msg.sender
///      for authority (e.g. Voter's constructor sets minter = _msgSender()),
///      so broadcasting from the *test* around a cross-contract call into
///      deployScript.deploy(...) only covers that one hop — deploy()'s own
///      nested `new X(...)` calls still originate from deployScript, not the
///      intended deployer. This harness inherits deploy() so broadcast starts
///      in the same frame that performs the nested creates.
contract DeployProtocolHarness is DeployProtocol {
    function deployWithBroadcast(
        Config memory cfg,
        address deployer
    ) external returns (Deployment memory d) {
        vm.startBroadcast(deployer);
        d = deploy(cfg, deployer);
        vm.stopBroadcast();
    }
}

/// @dev Most tests here drive DeployProtocol.deploy(Config, deployer) directly
///      under vm.prank rather than DeployProtocol.run(). run() only reads
///      PRIVATE_KEY/etc from the OS environment via vm.env*, and vm.setEnv
///      mutates real process-wide env vars that Foundry does NOT reset
///      between test functions (unlike EVM/storage state, which is
///      snapshotted per test). Driving deploy() directly with an explicit
///      Config avoids that cross-test leakage entirely. A single smoke test
///      (test_RunReadsEnvAndDeploys) exercises the env-var path end-to-end.
contract DeployProtocolTest is Test {
    uint256 constant DEPLOYER_KEY = 0xA11CE;
    // Must match DeployProtocol.INITIAL_SUPPLY (fixed in-contract, not configurable).
    uint256 constant INITIAL_SUPPLY = 10_000_000_000 ether;
    // Must match the emissionAmount literal hardcoded in DeployProtocol.deploy().
    uint256 constant EMISSION_AMOUNT = 10_000 ether;

    address deployer;
    address ccipAdmin = makeAddr("ccipAdmin");
    address team = makeAddr("team");
    MockLoanController loanController;
    DeployProtocol deployScript;
    DeployProtocolHarness harness;

    function setUp() public {
        deployer = vm.addr(DEPLOYER_KEY);
        loanController = new MockLoanController();
        deployScript = new DeployProtocol();
        harness = new DeployProtocolHarness();
    }

    function _baseConfig() internal view returns (DeployProtocol.Config memory) {
        return
            DeployProtocol.Config({
                ccipAdmin: ccipAdmin,
                team: team,
                loanController: address(loanController)
            });
    }

    function _deploy(
        DeployProtocol.Config memory cfg
    ) internal returns (DeployProtocol.Deployment memory d) {
        d = harness.deployWithBroadcast(cfg, deployer);
    }

    function test_FullDeployWiresEveryContract() public {
        DeployProtocol.Config memory cfg = _baseConfig();
        DeployProtocol.Deployment memory d = _deploy(cfg);

        // --- factory stack ---
        assertEq(
            PoolFactory(d.poolFactory).loanController(),
            address(loanController)
        );

        FactoryRegistry registry = FactoryRegistry(d.factoryRegistry);
        assertEq(registry.fallbackPoolFactory(), d.poolFactory);
        (address vrf, address gf) = registry.factoriesToPoolFactory(
            d.poolFactory
        );
        assertEq(vrf, d.votingRewardsFactory);
        assertEq(gf, d.gaugeFactory);
        assertEq(registry.managedRewardsFactory(), d.managedRewardsFactory);

        // --- ve / voter / rewards distributor cross-wiring ---
        VotingEscrow ve = VotingEscrow(d.ve);
        Voter voter = Voter(d.voter);
        RewardsDistributor rd = RewardsDistributor(d.rewardsDistributor);

        assertEq(ve.voter(), d.voter);
        assertEq(ve.distributor(), d.rewardsDistributor);
        assertEq(ve.token(), d.town);
        assertEq(ve.factoryRegistry(), d.factoryRegistry);
        assertEq(ve.artProxy(), d.artProxy);

        assertEq(voter.ve(), d.ve);
        assertEq(voter.factoryRegistry(), d.factoryRegistry);
        assertEq(voter.minter(), d.minter);
        assertTrue(voter.isWhitelistedToken(d.town));

        assertEq(rd.minter(), d.minter);

        // --- distribution buckets (fixed 18/15/20/37/9/1% split) ---
        TokenMinter tokenMinter = TokenMinter(d.tokenMinter);
        assertEq(tokenMinter.investorShare(), (INITIAL_SUPPLY * 1800) / 10_000);
        assertEq(tokenMinter.teamShare(), (INITIAL_SUPPLY * 1500) / 10_000);
        assertEq(
            tokenMinter.foundationShare(),
            (INITIAL_SUPPLY * 2000) / 10_000
        );
        assertEq(
            tokenMinter.communityShare(),
            (INITIAL_SUPPLY * 3700) / 10_000
        );
        assertEq(
            tokenMinter.ecosystemShare(),
            (INITIAL_SUPPLY * 900) / 10_000
        );
        assertEq(
            tokenMinter.liquidityShare(),
            (INITIAL_SUPPLY * 100) / 10_000
        );
    }

    function test_TeamOnlyWiringSkippedWhenTeamIsNotDeployer() public {
        // team (from _baseConfig) is a distinct address from `deployer`.
        DeployProtocol.Deployment memory d = _deploy(_baseConfig());

        Minter minter = Minter(d.minter);
        assertEq(address(minter.voter()), address(0));
        assertEq(address(minter.ve()), address(0));
        assertEq(address(minter.rewardsDistributor()), address(0));

        // Deployer-authority wiring must still have gone through.
        assertEq(VotingEscrow(d.ve).voter(), d.voter);
        assertEq(Voter(d.voter).minter(), d.minter);
    }

    function test_TeamOnlyWiringRunsWhenTeamIsDeployer() public {
        DeployProtocol.Config memory cfg = _baseConfig();
        cfg.team = deployer;
        DeployProtocol.Deployment memory d = _deploy(cfg);

        Minter minter = Minter(d.minter);
        assertEq(address(minter.voter()), d.voter);
        assertEq(address(minter.ve()), d.ve);
        assertEq(address(minter.rewardsDistributor()), d.rewardsDistributor);
    }

    function test_RevertWhen_TeamIsZeroAddress() public {
        DeployProtocol.Config memory cfg = _baseConfig();
        cfg.team = address(0);
        vm.expectRevert(ITokenMinter.ZeroAddress.selector);
        _deploy(cfg);
    }

    function test_RevertWhen_CcipAdminIsZeroAddress() public {
        DeployProtocol.Config memory cfg = _baseConfig();
        cfg.ccipAdmin = address(0);
        vm.expectRevert(ITokenMinter.ZeroAddress.selector);
        _deploy(cfg);
    }

    function test_NoForwarderIsWiredUpYet() public {
        // No ERC-2771 relayer has been chosen yet; both contracts are
        // deployed with forwarder = address(0) until that changes.
        DeployProtocol.Deployment memory d = _deploy(_baseConfig());

        assertEq(VotingEscrow(d.ve).forwarder(), address(0));
        assertEq(Voter(d.voter).forwarder(), address(0));
    }

    function test_EmissionAmountIsFixedWhenTeamIsDeployer() public {
        // emissionAmount is a hardcoded literal in deploy(), not configurable
        // via Config — only set on Minter at all when team == deployer.
        DeployProtocol.Config memory cfg = _baseConfig();
        cfg.team = deployer;
        DeployProtocol.Deployment memory d = _deploy(cfg);
        assertEq(Minter(d.minter).emissions(), EMISSION_AMOUNT);
    }

    /// @dev The only test that touches vm.setEnv, so there's nothing else in
    ///      this suite for its env-var writes to race against or leak into.
    function test_RunReadsEnvAndDeploys() public {
        vm.setEnv("PRIVATE_KEY", vm.toString(DEPLOYER_KEY));
        vm.setEnv("CCIP_ADMIN", vm.toString(ccipAdmin));
        vm.setEnv("TEAM", vm.toString(team));
        vm.setEnv("LOAN_CONTROLLER", vm.toString(address(loanController)));

        DeployProtocol.Deployment memory d = deployScript.run();

        assertTrue(d.voter != address(0));
        assertEq(VotingEscrow(d.ve).voter(), d.voter);
        assertEq(Voter(d.voter).minter(), d.minter);
        assertEq(Minter(d.minter).team(), team);
    }
}
