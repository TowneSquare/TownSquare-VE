// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IMinter} from "./interfaces/IMinter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Constants} from "./libraries/Constants.sol";

/*
 * @title Curve Fee Distribution modified for ve(3,3) emissions
 * @author Curve Finance, andrecronje
 * @author velodrome.finance, @figs999, @pegahcarter
 */
contract RewardsDistributor is IRewardsDistributor {
    using SafeERC20 for IERC20;

    /// @inheritdoc IRewardsDistributor
    uint256 public startTime;
    /// @inheritdoc IRewardsDistributor
    mapping(uint256 => uint256) public timeCursorOf;

    /// @inheritdoc IRewardsDistributor
    uint256 public lastTokenTime;
    uint256[1000000000000000] public tokensPerEpoch;

    /// @inheritdoc IRewardsDistributor
    IVotingEscrow public immutable ve;
    /// @inheritdoc IRewardsDistributor
    address public token;
    /// @inheritdoc IRewardsDistributor
    address public minter;
    /// @inheritdoc IRewardsDistributor
    uint256 public tokenLastBalance;

    constructor(address _ve) {
        uint256 _t = (block.timestamp / Constants.EPOCH) * Constants.EPOCH;
        startTime = _t;
        lastTokenTime = _t;
        ve = IVotingEscrow(_ve);
        address _token = ve.token();
        token = _token;
        minter = msg.sender;
        IERC20(_token).safeIncreaseAllowance(_ve, type(uint256).max);
    }

    function _checkpointToken() internal {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 toDistribute = tokenBalance - tokenLastBalance;
        tokenLastBalance = tokenBalance;

        uint256 t = lastTokenTime;
        uint256 sinceLast = block.timestamp - t;
        lastTokenTime = block.timestamp;
        uint256 thisEpoch = (t / Constants.EPOCH) * Constants.EPOCH;
        uint256 nextEpoch = 0;
        uint256 timestamp = block.timestamp;

        for (uint256 i = 0; i < 20; i++) {
            nextEpoch = thisEpoch + Constants.EPOCH;
            if (timestamp < nextEpoch) {
                if (sinceLast == 0 && timestamp == t) {
                    tokensPerEpoch[thisEpoch] += toDistribute;
                } else {
                    tokensPerEpoch[thisEpoch] +=
                        (toDistribute * (timestamp - t)) /
                        sinceLast;
                }
                break;
            } else {
                if (sinceLast == 0 && nextEpoch == t) {
                    tokensPerEpoch[thisEpoch] += toDistribute;
                } else {
                    tokensPerEpoch[thisEpoch] +=
                        (toDistribute * (nextEpoch - t)) /
                        sinceLast;
                }
            }
            t = nextEpoch;
            thisEpoch = nextEpoch;
        }
        emit CheckpointToken(timestamp, toDistribute);
    }

    /// @inheritdoc IRewardsDistributor
    function checkpointToken() external {
        if (msg.sender != minter) revert NotMinter();
        _checkpointToken();
    }

    function _claim(
        uint256 _tokenId,
        uint256 _lastTokenTime
    ) internal returns (uint256) {
        (
            uint256 toDistribute,
            uint256 epochStart,
            uint256 epochCursor
        ) = _claimable(_tokenId, _lastTokenTime);
        timeCursorOf[_tokenId] = epochCursor;
        if (toDistribute == 0) return 0;

        emit Claimed(_tokenId, epochStart, epochCursor, toDistribute);
        return toDistribute;
    }

    function _claimable(
        uint256 _tokenId,
        uint256 _lastTokenTime
    )
        internal
        view
        returns (
            uint256 toDistribute,
            uint256 epochCursorStart,
            uint256 epochCursor
        )
    {
        uint256 _startTime = startTime;
        epochCursor = timeCursorOf[_tokenId];
        epochCursorStart = epochCursor;

        // case where token does not exist
        uint256 maxUserEpoch = ve.userPointEpoch(_tokenId);
        if (maxUserEpoch == 0) return (0, epochCursorStart, epochCursor);

        // case where token exists but has never been claimed
        if (epochCursor == 0) {
            IVotingEscrow.UserPoint memory userPoint = ve.userPointHistory(
                _tokenId,
                1
            );
            epochCursor =
                (userPoint.ts / Constants.EPOCH) *
                Constants.EPOCH;
            epochCursorStart = epochCursor;
        }
        if (epochCursor >= _lastTokenTime)
            return (0, epochCursorStart, epochCursor);
        if (epochCursor < _startTime) epochCursor = _startTime;

        for (uint256 i = 0; i < 50; i++) {
            if (epochCursor >= _lastTokenTime) break;

            uint256 balance = ve.balanceOfNFTAt(
                _tokenId,
                epochCursor + Constants.EPOCH - 1
            );
            uint256 supply = ve.totalSupplyAt(
                epochCursor + Constants.EPOCH - 1
            );
            supply = supply == 0 ? 1 : supply;
            toDistribute += (balance * tokensPerEpoch[epochCursor]) / supply;
            epochCursor += Constants.EPOCH;
        }
    }

    /// @inheritdoc IRewardsDistributor
    function claimable(
        uint256 _tokenId
    ) external view returns (uint256 claimable_) {
        uint256 _lastTokenTime = (lastTokenTime / Constants.EPOCH) *
            Constants.EPOCH;
        (claimable_, , ) = _claimable(_tokenId, _lastTokenTime);
    }

    /// @inheritdoc IRewardsDistributor
    function claim(uint256 _tokenId) external returns (uint256) {
        uint256 currentEpochStart = (block.timestamp / Constants.EPOCH) *
            Constants.EPOCH;
        if (IMinter(minter).activePeriod() < currentEpochStart)
            revert UpdatePeriod();
        if (ve.escrowType(_tokenId) == IVotingEscrow.EscrowType.LOCKED)
            revert NotManagedOrNormalNFT();
        uint256 _timestamp = block.timestamp;
        uint256 _lastTokenTime = (lastTokenTime / Constants.EPOCH) *
            Constants.EPOCH;
        uint256 amount = _claim(_tokenId, _lastTokenTime);
        if (amount != 0) {
            IVotingEscrow.LockedBalance memory _locked = ve.locked(_tokenId);
            if (_timestamp >= _locked.end && !_locked.isPermanent) {
                address _owner = ve.ownerOf(_tokenId);
                IERC20(token).safeTransfer(_owner, amount);
            } else {
                ve.depositFor(_tokenId, amount);
            }
            tokenLastBalance -= amount;
        }
        return amount;
    }

    /// @inheritdoc IRewardsDistributor
    function claimMany(uint256[] calldata _tokenIds) external returns (bool) {
        uint256 currentEpochStart = (block.timestamp / Constants.EPOCH) *
            Constants.EPOCH;
        if (IMinter(minter).activePeriod() < currentEpochStart)
            revert UpdatePeriod();
        uint256 _timestamp = block.timestamp;
        uint256 _lastTokenTime = (lastTokenTime / Constants.EPOCH) *
            Constants.EPOCH;
        uint256 total = 0;
        uint256 _length = _tokenIds.length;

        for (uint256 i = 0; i < _length; i++) {
            uint256 _tokenId = _tokenIds[i];
            if (ve.escrowType(_tokenId) == IVotingEscrow.EscrowType.LOCKED)
                revert NotManagedOrNormalNFT();
            if (_tokenId == 0) break;
            uint256 amount = _claim(_tokenId, _lastTokenTime);
            if (amount != 0) {
                IVotingEscrow.LockedBalance memory _locked = ve.locked(
                    _tokenId
                );
                if (_timestamp >= _locked.end && !_locked.isPermanent) {
                    address _owner = ve.ownerOf(_tokenId);
                    IERC20(token).safeTransfer(_owner, amount);
                } else {
                    ve.depositFor(_tokenId, amount);
                }
                total += amount;
            }
        }
        if (total != 0) {
            tokenLastBalance -= total;
        }

        return true;
    }

    /// @inheritdoc IRewardsDistributor
    function setMinter(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        if (_minter == address(0)) revert ZeroAddress();
        minter = _minter;
    }
}
