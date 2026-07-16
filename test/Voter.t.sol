// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Town} from "../src/Town.sol";
import {PoolFactory} from "../src/factories/PoolFactory.sol";
import {GaugeFactory} from "../src/factories/GaugeFactory.sol";
import {VotingRewardsFactory} from "../src/factories/VotingRewardsFactory.sol";
import {ManagedRewardsFactory} from "../src/factories/ManagedRewardsFactory.sol";
import {FactoryRegistry} from "../src/factories/FactoryRegistry.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {Voter} from "../src/Voter.sol";
import {IVoter} from "../src/interfaces/IVoter.sol";
import {Gauge} from "../src/gauges/Gauge.sol";
import {Constants} from "../src/libraries/Constants.sol";
import {MockLoanController} from "./mocks/MockLoanController.sol";
import {MockMinter} from "./mocks/MockMinter.sol";

/// @notice Exercises Voter.sol's own behavior (voting, gauge lifecycle,
///         emissions distribution, governance/whitelist access control)
///         against real VotingEscrow/Gauge/IncentiveVotingReward contracts.
///         Deployment wiring itself is covered separately in
///         test/DeployProtocol.t.sol.
contract VoterTest is Test {
    uint256 constant MAXTIME = 4 * 365 days;
    uint256 constant INITIAL_SUPPLY = 1_000_000_000 ether;

    Town town;
    MockLoanController loanController;
    PoolFactory poolFactory;
    GaugeFactory gaugeFactory;
    VotingRewardsFactory votingRewardsFactory;
    ManagedRewardsFactory managedRewardsFactory;
    FactoryRegistry factoryRegistry;
    VotingEscrow ve;
    Voter voter;
    MockMinter minter;

    address distributor = makeAddr("distributor");
    address pool1 = makeAddr("pool1");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 t0;

    function setUp() public {
        town = new Town(INITIAL_SUPPLY, address(this));

        loanController = new MockLoanController();
        poolFactory = new PoolFactory(address(loanController));
        gaugeFactory = new GaugeFactory();
        votingRewardsFactory = new VotingRewardsFactory();
        managedRewardsFactory = new ManagedRewardsFactory();
        factoryRegistry = new FactoryRegistry(
            address(poolFactory),
            address(votingRewardsFactory),
            address(gaugeFactory),
            address(managedRewardsFactory)
        );

        ve = new VotingEscrow(address(0), address(town), address(factoryRegistry));
        voter = new Voter(address(0), address(ve), address(factoryRegistry));
        ve.setVoterAndDistributor(address(voter), distributor);

        minter = new MockMinter();
        address[] memory whitelist = new address[](1);
        whitelist[0] = address(town);
        voter.initialize(whitelist, address(minter));

        // Land solidly inside a voting window (epochVoteStart is 1h into the
        // epoch) so vote()/poke() work from the very first test action.
        t0 = 10 * Constants.EPOCH + 2 hours;
        vm.warp(t0);

        loanController.addPool(1, pool1);
    }

    function _nextEpoch() internal {
        vm.warp(block.timestamp + Constants.EPOCH);
    }

    function _createLockFor(
        address to,
        uint256 amount
    ) internal returns (uint256 tokenId) {
        town.transfer(to, amount);
        vm.startPrank(to);
        town.approve(address(ve), amount);
        tokenId = ve.createLock(amount, MAXTIME);
        vm.stopPrank();
    }

    function _createGaugeForPool1() internal returns (address gauge) {
        gauge = voter.createGauge(address(poolFactory), 1);
    }

    /// @dev notifyRewardAmount pulls `amount` from msg.sender via
    ///      safeTransferFrom, and only `minter` is authorized to call it.
    function _notifyReward(uint256 amount) internal {
        town.transfer(address(minter), amount);
        vm.startPrank(address(minter));
        town.approve(address(voter), amount);
        voter.notifyRewardAmount(amount);
        vm.stopPrank();
    }

    // ─── constructor / initialize ───────────────────────────────────────────

    function test_ConstructorSetsInitialState() public view {
        assertEq(voter.forwarder(), address(0));
        assertEq(voter.ve(), address(ve));
        assertEq(voter.factoryRegistry(), address(factoryRegistry));
        assertEq(voter.governor(), address(this));
        assertEq(voter.epochGovernor(), address(this));
        assertEq(voter.emergencyCouncil(), address(this));
        assertEq(voter.maxVotingNum(), 30);
    }

    function test_InitializeWhitelistsTokensAndSetsMinter() public view {
        assertTrue(voter.isWhitelistedToken(address(town)));
        assertEq(voter.minter(), address(minter));
    }

    function test_RevertWhen_InitializeCalledByNonMinter() public {
        // minter was already swapped to `minter` in setUp, so `address(this)`
        // (the original deployer) is no longer authorized.
        address[] memory tokens = new address[](0);
        vm.expectRevert(IVoter.NotMinter.selector);
        voter.initialize(tokens, address(this));
    }

    // ─── governance setters ─────────────────────────────────────────────────

    function test_SetGovernor() public {
        voter.setGovernor(alice);
        assertEq(voter.governor(), alice);
    }

    function test_RevertWhen_SetGovernorByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IVoter.NotGovernor.selector);
        voter.setGovernor(alice);
    }

    function test_RevertWhen_SetGovernorToZeroAddress() public {
        vm.expectRevert(IVoter.ZeroAddress.selector);
        voter.setGovernor(address(0));
    }

    function test_RevertWhen_SetEmergencyCouncilByNonCouncil() public {
        vm.prank(alice);
        vm.expectRevert(IVoter.NotEmergencyCouncil.selector);
        voter.setEmergencyCouncil(alice);
    }

    function test_SetMaxVotingNum() public {
        voter.setMaxVotingNum(50);
        assertEq(voter.maxVotingNum(), 50);
    }

    function test_RevertWhen_SetMaxVotingNumTooLow() public {
        vm.expectRevert(IVoter.MaximumVotingNumberTooLow.selector);
        voter.setMaxVotingNum(1);
    }

    function test_RevertWhen_SetMaxVotingNumSameValue() public {
        vm.expectRevert(IVoter.SameValue.selector);
        voter.setMaxVotingNum(30);
    }

    // ─── whitelist ───────────────────────────────────────────────────────────

    function test_WhitelistToken() public {
        address token = makeAddr("token");
        voter.whitelistToken(token, true);
        assertTrue(voter.isWhitelistedToken(token));
    }

    function test_RevertWhen_WhitelistTokenByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IVoter.NotGovernor.selector);
        voter.whitelistToken(address(town), false);
    }

    function test_WhitelistNFT() public {
        voter.whitelistNFT(1, true);
        assertTrue(voter.isWhitelistedNFT(1));
    }

    function test_RevertWhen_WhitelistNFTByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IVoter.NotGovernor.selector);
        voter.whitelistNFT(1, true);
    }

    // ─── createGauge ─────────────────────────────────────────────────────────

    function test_CreateGaugeByGovernorBypassesUnregisteredPoolCheck() public {
        // poolId 2 was never registered via loanController.addPool, so
        // isPool(2) is false and getPool(2) resolves to address(0) — a
        // non-governor caller would hit NotAPool (see the revert test
        // below), but the governor may create a gauge regardless.
        assertFalse(loanController.isPoolAdded(2));
        address gauge = voter.createGauge(address(poolFactory), 2);
        assertTrue(voter.isGauge(gauge));
        assertTrue(voter.isAlive(gauge));
        assertEq(voter.gauges(address(0)), gauge);
        assertEq(voter.length(), 1);
    }

    function test_CreateGaugeByNonGovernorForRegisteredPool() public {
        vm.prank(alice);
        address gauge = voter.createGauge(address(poolFactory), 1);
        assertEq(voter.gauges(pool1), gauge);
    }

    function test_RevertWhen_CreateGaugeByNonGovernorForUnregisteredPool()
        public
    {
        vm.prank(alice);
        vm.expectRevert(IVoter.NotAPool.selector);
        voter.createGauge(address(poolFactory), 99);
    }

    function test_RevertWhen_CreateGaugeTwiceForSamePool() public {
        _createGaugeForPool1();
        vm.expectRevert(IVoter.GaugeExists.selector);
        voter.createGauge(address(poolFactory), 1);
    }

    function test_RevertWhen_CreateGaugeWithUnapprovedFactory() public {
        PoolFactory rogueFactory = new PoolFactory(address(loanController));
        vm.expectRevert(IVoter.FactoryPathNotApproved.selector);
        voter.createGauge(address(rogueFactory), 1);
    }

    // ─── setGaugeRewardSplit ─────────────────────────────────────────────────

    function test_RevertWhen_SetGaugeRewardSplitByNonGovernor() public {
        address gauge = _createGaugeForPool1();
        vm.prank(alice);
        vm.expectRevert(IVoter.NotGovernor.selector);
        voter.setGaugeRewardSplit(gauge, 5000, 5000);
    }

    function test_RevertWhen_SetGaugeRewardSplitNotAGauge() public {
        vm.expectRevert(IVoter.NotAGauge.selector);
        voter.setGaugeRewardSplit(alice, 5000, 5000);
    }

    // ─── killGauge / reviveGauge ─────────────────────────────────────────────

    function test_KillGaugeReturnsClaimableToMinter() public {
        address gauge = _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;
        vm.prank(alice);
        voter.vote(tokenId, poolVote, weights);

        _notifyReward(1_000 ether);
        voter.updateFor(gauge); // claimable[] only refreshes when _updateFor runs

        uint256 minterBalanceBefore = town.balanceOf(address(minter));
        uint256 claimableBefore = voter.claimable(gauge);
        assertGt(claimableBefore, 0);

        voter.killGauge(gauge);

        assertFalse(voter.isAlive(gauge));
        assertEq(voter.claimable(gauge), 0);
        assertEq(
            town.balanceOf(address(minter)),
            minterBalanceBefore + claimableBefore
        );
    }

    function test_RevertWhen_KillGaugeByNonCouncil() public {
        address gauge = _createGaugeForPool1();
        vm.prank(alice);
        vm.expectRevert(IVoter.NotEmergencyCouncil.selector);
        voter.killGauge(gauge);
    }

    function test_RevertWhen_KillGaugeAlreadyKilled() public {
        address gauge = _createGaugeForPool1();
        voter.killGauge(gauge);
        vm.expectRevert(IVoter.GaugeAlreadyKilled.selector);
        voter.killGauge(gauge);
    }

    function test_ReviveGauge() public {
        address gauge = _createGaugeForPool1();
        voter.killGauge(gauge);
        voter.reviveGauge(gauge);
        assertTrue(voter.isAlive(gauge));
    }

    function test_RevertWhen_ReviveGaugeNotKilled() public {
        address gauge = _createGaugeForPool1();
        vm.expectRevert(IVoter.GaugeAlreadyRevived.selector);
        voter.reviveGauge(gauge);
    }

    // ─── vote / reset / poke ─────────────────────────────────────────────────

    function test_VoteRecordsWeightsAndDeposits() public {
        address gauge = _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        uint256 veWeight = ve.balanceOfNFT(tokenId);

        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;

        vm.prank(alice);
        voter.vote(tokenId, poolVote, weights);

        assertEq(voter.usedWeights(tokenId), veWeight);
        assertEq(voter.weights(pool1), veWeight);
        assertEq(voter.votes(tokenId, pool1), veWeight);
        assertEq(voter.totalWeight(), veWeight);
        assertEq(voter.lastVoted(tokenId), block.timestamp);
        assertTrue(gauge != address(0));
    }

    function test_RevertWhen_VoteByNonOwner() public {
        _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;

        vm.prank(bob);
        vm.expectRevert(IVoter.NotApprovedOrOwner.selector);
        voter.vote(tokenId, poolVote, weights);
    }

    function test_RevertWhen_VoteWithUnequalLengths() public {
        _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](2);
        poolVote[0] = pool1;

        vm.prank(alice);
        vm.expectRevert(IVoter.UnequalLengths.selector);
        voter.vote(tokenId, poolVote, weights);
    }

    function test_RevertWhen_VoteExceedsMaxVotingNum() public {
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](31);
        uint256[] memory weights = new uint256[](31);
        for (uint256 i = 0; i < 31; i++) {
            poolVote[i] = address(uint160(i + 1));
            weights[i] = 1;
        }

        vm.prank(alice);
        vm.expectRevert(IVoter.TooManyPools.selector);
        voter.vote(tokenId, poolVote, weights);
    }

    function test_RevertWhen_VoteForNonexistentGauge() public {
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1; // no gauge created for pool1 in this test

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IVoter.GaugeDoesNotExist.selector, pool1)
        );
        voter.vote(tokenId, poolVote, weights);
    }

    function test_RevertWhen_VoteTwiceInSameEpoch() public {
        _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;

        vm.startPrank(alice);
        voter.vote(tokenId, poolVote, weights);
        vm.expectRevert(IVoter.AlreadyVotedOrDeposited.selector);
        voter.vote(tokenId, poolVote, weights);
        vm.stopPrank();
    }

    function test_RevertWhen_VoteBeforeVoteWindowOpens() public {
        _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        // Rewind to just before this epoch's voting window opened.
        vm.warp(Constants.EPOCH * (t0 / Constants.EPOCH));

        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;

        vm.prank(alice);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.vote(tokenId, poolVote, weights);
    }

    function test_ResetClearsVotesInNextEpoch() public {
        _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;

        vm.prank(alice);
        voter.vote(tokenId, poolVote, weights);

        _nextEpoch();

        vm.prank(alice);
        voter.reset(tokenId);

        assertEq(voter.usedWeights(tokenId), 0);
        assertEq(voter.weights(pool1), 0);
        assertEq(voter.votes(tokenId, pool1), 0);
        assertEq(voter.totalWeight(), 0);
    }

    function test_PokeRecomputesWeightsSameEpoch() public {
        _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;

        vm.prank(alice);
        voter.vote(tokenId, poolVote, weights);
        uint256 usedBefore = voter.usedWeights(tokenId);

        vm.prank(alice);
        voter.poke(tokenId);

        assertEq(voter.usedWeights(tokenId), usedBefore);
        assertEq(voter.weights(pool1), usedBefore);
    }

    // ─── notifyRewardAmount / distribute ─────────────────────────────────────

    function test_RevertWhen_NotifyRewardAmountByNonMinter() public {
        vm.expectRevert(IVoter.NotMinter.selector);
        voter.notifyRewardAmount(1 ether);
    }

    function test_NotifyRewardAmountByMinterPullsTokensAndUpdatesIndex()
        public
    {
        _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;
        vm.prank(alice);
        voter.vote(tokenId, poolVote, weights);

        _notifyReward(100 ether);
        voter.updateFor(voter.gauges(pool1)); // claimable[] only refreshes when _updateFor runs

        assertEq(town.balanceOf(address(voter)), 100 ether);
        assertGt(voter.claimable(voter.gauges(pool1)), 0);
    }

    function test_DistributeSendsClaimableToGaugeByRange() public {
        address gauge = _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;
        vm.prank(alice);
        voter.vote(tokenId, poolVote, weights);

        _notifyReward(1_000 ether);

        voter.distribute(0, voter.length());

        assertApproxEqAbs(town.balanceOf(gauge), 1_000 ether, 1e6);
        assertEq(voter.claimable(gauge), 0);
    }

    function test_DistributeSendsClaimableToGaugeByArray() public {
        address gauge = _createGaugeForPool1();
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = pool1;
        weights[0] = 1;
        vm.prank(alice);
        voter.vote(tokenId, poolVote, weights);

        _notifyReward(1_000 ether);

        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        voter.distribute(gauges);

        assertApproxEqAbs(town.balanceOf(gauge), 1_000 ether, 1e6);
    }

    // ─── claim access control ────────────────────────────────────────────────

    function test_RevertWhen_ClaimIncentivesByNonOwner() public {
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory incentives = new address[](0);
        address[][] memory tokens = new address[][](0);

        vm.prank(bob);
        vm.expectRevert(IVoter.NotApprovedOrOwner.selector);
        voter.claimIncentives(incentives, tokens, tokenId);
    }

    function test_RevertWhen_ClaimFeesByNonOwner() public {
        uint256 tokenId = _createLockFor(alice, 1_000 ether);
        address[] memory fees = new address[](0);
        address[][] memory tokens = new address[][](0);

        vm.prank(bob);
        vm.expectRevert(IVoter.NotApprovedOrOwner.selector);
        voter.claimFees(fees, tokens, tokenId);
    }
}
