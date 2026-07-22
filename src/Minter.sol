// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IMinter} from "./interfaces/IMinter.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {ITown} from "./interfaces/ITown.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Constants} from "./libraries/Constants.sol";

/// @title Minter
/// @notice Processes epoch emissions and ve rebases for TownSq.
///         Holds a token balance funded at deployment; no new tokens are minted.
contract Minter is IMinter {
    using SafeERC20 for ITown;
    using Math for uint256;

    ITown public town;
    IVoter public voter;
    IVotingEscrow public ve;
    IRewardsDistributor public rewardsDistributor;

    uint256 public activePeriod;
    uint256 public emissions;

    address public team;
    address public pendingTeam;

    address[] public treasuries;

    constructor(address _town, address _team) {
        if (_town == address(0) || _team == address(0)) revert ZeroAddress();
        town = ITown(_town);
        team = _team;
        activePeriod = (block.timestamp / Constants.EPOCH) * Constants.EPOCH;
    }

    modifier onlyTeam() {
        if (msg.sender != team) revert NotTeam();
        _;
    }

    // ─── Team management ─────────────────────────────────────────────────────

    function setTeam(address _team) external onlyTeam {
        if (_team == address(0)) revert ZeroAddress();
        pendingTeam = _team;
    }

    function acceptTeam() external {
        if (msg.sender != pendingTeam) revert NotPendingTeam();
        team = pendingTeam;
        delete pendingTeam;
        emit AcceptTeam(team);
    }

    // ─── Configuration ────────────────────────────────────────────────────────

    function setVoter(address _voter) external onlyTeam {
        if (_voter == address(0)) revert ZeroAddress();
        voter = IVoter(_voter);
    }

    function setVe(address _ve) external onlyTeam {
        if (_ve == address(0)) revert ZeroAddress();
        ve = IVotingEscrow(_ve);
    }

    function setRewardsDistributor(
        address _rewardsDistributor
    ) external onlyTeam {
        if (_rewardsDistributor == address(0)) revert ZeroAddress();
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
    }

    function setEmissionAmount(uint256 _emission) external onlyTeam {
        emissions = _emission;
        emit EmissionAmountSet(emissions);
    }

    function addTreasury(address _treasury) external onlyTeam {
        if (_treasury == address(0)) revert ZeroAddress();
        treasuries.push(_treasury);
    }

    function removeTreasury(address _treasury) external onlyTeam {
        uint256 len = treasuries.length;
        for (uint256 i = 0; i < len; i++) {
            if (treasuries[i] == _treasury) {
                treasuries[i] = treasuries[len - 1];
                treasuries.pop();
                break;
            }
        }
    }

    // ─── Emissions ────────────────────────────────────────────────────────────

    function circulatingSupply() public view returns (uint256) {
        uint256 excluded = town.balanceOf(address(this));
        uint256 len = treasuries.length;
        for (uint256 i = 0; i < len; i++) {
            excluded += town.balanceOf(treasuries[i]);
        }
        return town.totalSupply() - excluded;
    }

    function calculateGrowth(uint256 _minted) public view returns (uint256) {
        if (activePeriod == 0) return 0;
        uint256 _veTotal   = ve.totalSupplyAt(activePeriod - 1);
        uint256 _townTotal = circulatingSupply();
        if (_townTotal == 0) return 0;
        return (((((_minted * _veTotal) / _townTotal) * _veTotal) / _townTotal) * _veTotal) / _townTotal / 2;
    }

    /// @inheritdoc IMinter
    function updatePeriod() external returns (uint256 _period) {
        _period = activePeriod;
        if (block.timestamp >= _period + Constants.EPOCH) {
            _period = (block.timestamp / Constants.EPOCH) * Constants.EPOCH;
            activePeriod = _period;

            uint256 _growth = calculateGrowth(emissions);
            uint256 _required = _growth + emissions;

            if (town.balanceOf(address(this)) < _required)
                revert NotEnoughTown();

            town.safeTransfer(address(rewardsDistributor), _growth);
            rewardsDistributor.checkpointToken();

            town.safeIncreaseAllowance(address(voter), emissions);
            voter.notifyRewardAmount(emissions);

            emit Mint(msg.sender, emissions);
        }
    }
}
