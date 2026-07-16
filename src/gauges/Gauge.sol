// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ERC2771Context
} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {
    ReentrancyGuardTransient
} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {TownsquareTimeLibrary} from "../libraries/TownsquareTimeLibrary.sol";

import {IGaugeFactory} from "../interfaces/factories/IGaugeFactory.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Gauge is Context, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    bytes32 public root;

    address public immutable voter;

    address public immutable gaugeFactory;

    address public immutable rewardToken;

    uint256 public periodFinish;

    uint256 public collateralRewardRate;

    uint256 public borrowRewardRate;

    uint256 public collateralBps = 4000;

    uint256 public borrowBps = 6000;

    uint256 public lastUpdateTime;

    uint256 public collateralRewardPerTokenStored;

    uint256 public borrowRewardPerTokenStored;

    uint256 public totalRewardRate;

    uint256 public totalCollateral;

    uint256 internal constant PRECISION = 10 ** 18;

    // mapping(address => uint256) public collateralRewards;

    // mapping(address => uint256) public borrowRewards;

    mapping(uint256 => uint256) public borrowRewardRateByEpoch;

    mapping(uint256 => uint256) public collateralRewardRateByEpoch;

    error NotAlive();
    error NotAuthorized();
    error NotVoter();
    error NotTeam();
    error RewardRateTooHigh();
    error ZeroAmount();
    error ZeroRewardRate();
    error MerkleRootNotSet();
    error InvalidProof();
    error InsufficientContractBalance();
    error ZeroRoot();
    error InvalidSplit();

    event NotifyReward(address indexed from, uint256 amount);
    event MerkleRootUpdated(bytes32 root);
    event Claimed(address indexed sender, uint256 amount);
    event RewardSplitUpdated(uint256 collateralBps, uint256 borrowBps);

    constructor(
        address _rewardToken, /// TOWN
        address _voter
    ) {
        rewardToken = _rewardToken;
        voter = _voter;
        gaugeFactory = msg.sender;
    }

    function setRewardSplit(uint256 _collateralBps, uint256 _borrowBps) external {
        if (_msgSender() != voter) revert NotVoter();
        if (_collateralBps + _borrowBps != 10000) revert InvalidSplit();
        collateralBps = _collateralBps;
        borrowBps = _borrowBps;
        emit RewardSplitUpdated(_collateralBps, _borrowBps);
    }

    function setMerkleRoot(bytes32 _root) external {
        address sender = _msgSender();
        if (sender != voter) revert NotVoter();
        if (_root == bytes32(0)) revert ZeroRoot();
        root = _root;
        emit MerkleRootUpdated(_root);
    }

    function getReward(
        uint256 reward,
        bytes32[] calldata proof
    ) external nonReentrant {
        if (root == bytes32(0)) revert MerkleRootNotSet();

        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, reward)))
        );
        if (!MerkleProof.verify(proof, root, leaf)) revert InvalidProof();

        if (reward == 0) revert ZeroAmount();
        if (IERC20(rewardToken).balanceOf(address(this)) < reward)
            revert InsufficientContractBalance();

        IERC20(rewardToken).safeTransfer(msg.sender, reward);

        emit Claimed(msg.sender, reward);
    }

    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * totalRewardRate;
    }

    // function setTotalCollateral(uint256 _totalCollateral) external {
    //     totalCollateral = _totalCollateral;
    // }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    // function collateralRewardPerToken() public view returns (uint256) {
    //     if (totalCollateral == 0) {
    //         return collateralRewardPerTokenStored;
    //     }

    //     return
    //         collateralRewardPerTokenStored +
    //         ((lastTimeRewardApplicable() - lastUpdateTime) *
    //             collateralRewardRate *
    //             PRECISION) /
    //         totalCollateral;
    // }

    // function updateCollateralRewardPerTokenStored() external {
    //     collateralRewardPerTokenStored = collateralRewardPerToken();
    // }

    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        address sender = _msgSender();
        if (sender != voter) revert NotVoter();
        if (_amount == 0) revert ZeroAmount();
        //_claimFees();
        _notifyRewardAmount(sender, _amount);
    }

    function notifyRewardWithoutClaim(uint256 _amount) external nonReentrant {
        address sender = _msgSender();
        if (sender != IGaugeFactory(gaugeFactory).notifyAdmin())
            revert NotAuthorized();
        if (_amount == 0) revert ZeroAmount();
        _notifyRewardAmount(sender, _amount);
    }

    function _notifyRewardAmount(address sender, uint256 _amount) internal {
        // rewardPerTokenStored = rewardPerToken();
        uint256 timestamp = block.timestamp;
        uint256 timeUntilNext = TownsquareTimeLibrary.epochNext(timestamp) -
            timestamp;

        uint256 collateralAmount = (_amount * collateralBps) / 10000;
        uint256 borrowAmount = (_amount * borrowBps) / 10000;

        if (timestamp >= periodFinish) {
            IERC20(rewardToken).safeTransferFrom(
                sender,
                address(this),
                _amount
            );
            //rewardRate = _amount / timeUntilNext;
            collateralRewardRate = collateralAmount / timeUntilNext;
            borrowRewardRate = borrowAmount / timeUntilNext;
        } else {
            uint256 _remaining = periodFinish - timestamp;
            //uint256 _leftover = _remaining * rewardRate;
            uint256 _collateralLeftover = _remaining * collateralRewardRate;
            uint256 _borrowLeftover = _remaining * borrowRewardRate;
            IERC20(rewardToken).safeTransferFrom(
                sender,
                address(this),
                _amount
            );
            //rewardRate = (_amount + _leftover) / timeUntilNext;
            collateralRewardRate =
                (collateralAmount + _collateralLeftover) /
                timeUntilNext;
            borrowRewardRate = (borrowAmount + _borrowLeftover) / timeUntilNext;
        }
        borrowRewardRateByEpoch[
            TownsquareTimeLibrary.epochStart(timestamp)
        ] = borrowRewardRate;

        collateralRewardRateByEpoch[
            TownsquareTimeLibrary.epochStart(timestamp)
        ] = collateralRewardRate;

        totalRewardRate = collateralRewardRate + borrowRewardRate;

        if (totalRewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (totalRewardRate > balance / timeUntilNext)
            revert RewardRateTooHigh();

        lastUpdateTime = timestamp;
        periodFinish = timestamp + timeUntilNext;
        emit NotifyReward(sender, _amount);
    }
}
