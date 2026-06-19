// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IReward} from "../interfaces/IReward.sol";
import {IGauge} from "../interfaces/IGauge.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
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
import {Utils} from "../libraries/Utils.sol";
import {IGaugeFactory} from "../interfaces/factories/IGaugeFactory.sol";
import {IAccountManager} from "../interfaces/IAccountManager.sol";
import {Messages} from "../libraries/Message.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";

/// @title Velodrome V2 Gauge
/// @author veldorome.finance, @figs999, @pegahcarter
/// @notice Gauge contract for distribution of emissions by address
contract Gauge is IGauge, ERC2771Context, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    /// @inheritdoc IGauge
    address public immutable stakingToken;
    /// @inheritdoc IGauge
    address public immutable rewardToken;

    address public immutable accountManager;

    address public immutable loanManager;
    /// @inheritdoc IGauge
    address public immutable feesVotingReward;
    /// @inheritdoc IGauge
    address public immutable voter;
    /// @inheritdoc IGauge
    address public immutable gaugeFactory;
    /// @inheritdoc IGauge
    bool public immutable isPool;

    uint256 internal constant DURATION = 7 days; // rewards are released over 7 days

    uint256 internal constant PRECISION = 10 ** 18;

    /// @inheritdoc IGauge
    uint256 public periodFinish;
    /// @inheritdoc IGauge
    uint256 public collateralRewardRate;

    uint256 public borrowRewardRate;
    /// @inheritdoc IGauge
    uint256 public lastUpdateTime;
    /// @inheritdoc IGauge
    uint256 public collateralRewardPerTokenStored;

    uint256 public borrowRewardPerTokenStored;
    /// @inheritdoc IGauge
    uint256 public totalCollateral;
    /// @inheritdoc IGauge
    uint256 public totalBorrow;

    uint256 public totalRewardRate;
    /// @inheritdoc IGauge
    mapping(address => uint256) public balanceOf;
    /// @inheritdoc IGauge
    mapping(address => uint256) public userCollateralRewardPerTokenPaid;
    /// @inheritdoc IGauge
    mapping(address => uint256) public userBorrowRewardPerTokenPaid;
    /// @inheritdoc IGauge
    mapping(address => uint256) public collateralRewards;
    /// @inheritdoc IGauge
    mapping(address => uint256) public borrowRewards;
    /// @inheritdoc IGauge
    mapping(uint256 => uint256) public collateralRewardRateByEpoch;
    /// @inheritdoc IGauge
    mapping(uint256 => uint256) public borrowRewardRateByEpoch;

    /// @inheritdoc IGauge
    uint256 public fees0;
    /// @inheritdoc IGauge
    uint256 public fees1;

    constructor(
        address _forwarder,
        address _pool,
        address _rewardToken, /// TOWN
        address _voter,
        address _accountManager,
        address _loanManager,
        bool _isPool
    ) ERC2771Context(_forwarder) {
        stakingToken = _pool;
        rewardToken = _rewardToken;
        feesVotingReward = address(0);
        voter = _voter;
        accountManager = _accountManager;
        loanManager = _loanManager;
        isPool = _isPool;
        gaugeFactory = msg.sender;
    }

    // function rewardPerToken() public view returns (uint256) {
    //     if (totalSupply == 0) {
    //         return rewardPerTokenStored;
    //     }
    //     return
    //         rewardPerTokenStored +
    //         ((lastTimeRewardApplicable() - lastUpdateTime) *
    //             rewardRate *
    //             PRECISION) /
    //         totalSupply;
    // }

    function collateralRewardPerToken() public view returns (uint256) {
        if (totalCollateral == 0) {
            return collateralRewardPerTokenStored;
        }

        return
            collateralRewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                collateralRewardRate *
                PRECISION) /
            totalCollateral;
    }

    function borrowRewardPerToken() public view returns (uint256) {
        if (totalBorrow == 0) {
            return borrowRewardPerTokenStored;
        }
        return
            borrowRewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                borrowRewardRate *
                PRECISION) /
            totalBorrow;
    }

    /// @inheritdoc IGauge
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /// @inheritdoc IGauge
    function getReward(
        address _account,
        bytes32 _accountId,
        uint16 _chainId,
        bytes32[] memory _accountLoans
    ) external nonReentrant {
        address sender = _msgSender();
        bool isRegistered = IAccountManager(accountManager)
            .isAddressRegisteredToAccount(
                _accountId,
                _chainId,
                Messages.convertEVMAddressToGenericAddress(_account)
            );
        if (sender != _account && sender != voter && !isRegistered)
            revert NotAuthorized();

        _updateRewards(_account, _accountLoans, _chainId);

        uint256 reward;

        if (collateralRewards[_account] > 0) {
            reward += collateralRewards[_account];
            collateralRewards[_account] = 0;
        }

        if (borrowRewards[_account] > 0) {
            reward += borrowRewards[_account];
            borrowRewards[_account] = 0;
        }

        if (reward > 0) {
            //rewards[_account] = 0;
            IERC20(rewardToken).safeTransfer(_account, reward);
            emit ClaimRewards(_account, reward);
        }
    }

    /// @inheritdoc IGauge
    function earned(
        address _account,
        bytes32[] memory _accountLoans,
        uint16 _chainId
    ) public view returns (uint256, uint256) {
        bytes32 userAccountId = IAccountManager(accountManager)
            .getAccountIdOfAddressOnChain(
                Messages.convertEVMAddressToGenericAddress(_account),
                _chainId
            );
        uint256 collateralBalance;
        uint256 borrowBalance;
        uint256 loanCnt = _accountLoans.length;
        uint256 poolId = IPool(stakingToken).getPoolId();

        for (uint256 i = 0; i < loanCnt; i++) {
            (
                bytes32 accountId,
                uint16 loanTypeId,
                uint8[] memory colPools,
                uint8[] memory borPools,
                ILoanManager.UserLoanCollateral[] memory collateral,
                ILoanManager.UserLoanBorrow[] memory borrow
            ) = ILoanManager(loanManager).getUserLoan(_accountLoans[i]); // need to add loanManger address
            /// check user is the owner of the loans

            if (userAccountId != accountId) {
                revert NotAuthorized();
            }

            for (uint256 i = 0; i < colPools.length; i++) {
                if (colPools[i] == poolId) {
                    collateralBalance += collateral[i].balance; // Use fToken balance
                    break;
                }
            }

            for (uint256 i = 0; i < borPools.length; i++) {
                if (borPools[i] == poolId) {
                    borrowBalance += borrow[i].amount;
                    break;
                }
            }
        }

        uint256 depositInterestIndexAtT = IPool(stakingToken)
            .getDepositData()
            .interestIndex;

        // convert fToken to underlying amount
        uint256 collateralReward = (Utils.toUnderlingAmount(
            collateralBalance,
            depositInterestIndexAtT
        ) *
            (collateralRewardPerToken() -
                userCollateralRewardPerTokenPaid[_account])) /
            PRECISION +
            collateralRewards[_account];

        uint256 borrowReward = (borrowBalance *
            (borrowRewardPerToken() - userBorrowRewardPerTokenPaid[_account])) /
            PRECISION +
            borrowRewards[_account];

        return (collateralReward, borrowReward);
    }

    function _updateRewards(
        address _account,
        bytes32[] memory accountLoans,
        uint16 chainId
    ) internal {
        totalCollateral = IPool(stakingToken).getDepositData().totalAmount;
        totalBorrow =
            IPool(stakingToken).getStableBorrowData().totalAmount +
            IPool(stakingToken).getVariableBorrowData().totalAmount;
        collateralRewardPerTokenStored = collateralRewardPerToken();
        borrowRewardPerTokenStored = borrowRewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        (uint256 collateralReward, uint256 borrowReward) = earned(
            _account,
            accountLoans,
            chainId
        );
        collateralRewards[_account] = collateralReward;
        borrowRewards[_account] = borrowReward;
        //userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        userCollateralRewardPerTokenPaid[
            _account
        ] = collateralRewardPerTokenStored;

        userBorrowRewardPerTokenPaid[_account] = borrowRewardPerTokenStored;
    }

    /// @inheritdoc IGauge
    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * totalRewardRate;
    }

    /// @inheritdoc IGauge
    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        address sender = _msgSender();
        if (sender != voter) revert NotVoter();
        if (_amount == 0) revert ZeroAmount();
        //_claimFees();
        _notifyRewardAmount(sender, _amount);
    }

    /// @inheritdoc IGauge
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

        uint256 collateralAmount = (_amount * 4000) / 10000;
        uint256 borrowAmount = (_amount * 6000) / 10000;

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
