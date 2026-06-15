// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ITokenMinter} from "./interfaces/ITokenMinter.sol";
import {ITown} from "./interfaces/ITown.sol";
import {Town} from "./Town.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TokenMinter
/// @author TownSq, @pelumi527
/// @notice Deploys TOWN, holds the initial supply, and distributes it
///         across six allocation buckets. Epoch emissions are handled
///         separately by the Minter contract.
contract TokenMinter is ITokenMinter {
    using SafeERC20 for ITown;
    using Math for uint256;

    /// @inheritdoc ITokenMinter
    ITown public town;

    /// @inheritdoc ITokenMinter
    uint256 public constant MAX_BPS = 10_000;

    /// @inheritdoc ITokenMinter
    uint256 public investorShare;
    /// @inheritdoc ITokenMinter
    uint256 public teamShare;
    /// @inheritdoc ITokenMinter
    uint256 public foundationShare;
    /// @inheritdoc ITokenMinter
    uint256 public communityShare;
    /// @inheritdoc ITokenMinter
    uint256 public ecosystemShare;
    /// @inheritdoc ITokenMinter
    uint256 public liquidityShare;

    /// @inheritdoc ITokenMinter
    address public team;
    /// @inheritdoc ITokenMinter
    address public pendingTeam;

    constructor(
        uint256 initialSupply,
        address admin,
        address _team,
        uint256 _investorPercent,
        uint256 _teamPercent,
        uint256 _foundationPercent,
        uint256 _communityPercent,
        uint256 _ecosystemPercent,
        uint256 _liquidityPercent
    ) {
        if (_team == address(0) || admin == address(0)) revert ZeroAddress();

        uint256 totalPercent = _investorPercent +
            _teamPercent +
            _foundationPercent +
            _communityPercent +
            _ecosystemPercent +
            _liquidityPercent;
        if (totalPercent != MAX_BPS) revert InvalidTotalPercent();

        town = new Town(initialSupply, admin);
        team = _team;

        uint256 totalSupply = town.totalSupply();
        investorShare = totalSupply.mulDiv(_investorPercent, MAX_BPS);
        teamShare = totalSupply.mulDiv(_teamPercent, MAX_BPS);
        foundationShare = totalSupply.mulDiv(_foundationPercent, MAX_BPS);
        communityShare = totalSupply.mulDiv(_communityPercent, MAX_BPS);
        ecosystemShare = totalSupply.mulDiv(_ecosystemPercent, MAX_BPS);
        liquidityShare = totalSupply.mulDiv(_liquidityPercent, MAX_BPS);
    }

    modifier onlyTeam() {
        if (msg.sender != team) revert NotTeam();
        _;
    }

    // ─── Team management ─────────────────────────────────────────────────────

    /// @inheritdoc ITokenMinter
    function setTeam(address _team) external onlyTeam {
        if (_team == address(0)) revert ZeroAddress();
        pendingTeam = _team;
    }

    /// @inheritdoc ITokenMinter
    function acceptTeam() external {
        if (msg.sender != pendingTeam) revert NotPendingTeam();
        team = pendingTeam;
        delete pendingTeam;
        emit AcceptTeam(team);
    }

    // ─── Distribution ─────────────────────────────────────────────────────────

    /// @inheritdoc ITokenMinter
    function distribute(
        Distribution _distribution,
        uint256 _amount,
        address _to
    ) external onlyTeam {
        if (_amount == 0) revert ZeroAmount();
        if (_to == address(0)) revert ZeroAddress();

        // Decrement share before transfer: underflow reverts if _amount exceeds bucket.
        if (_distribution == Distribution.INVESTOR) {
            investorShare -= _amount;
        } else if (_distribution == Distribution.TEAM) {
            teamShare -= _amount;
        } else if (_distribution == Distribution.FOUNDATION) {
            foundationShare -= _amount;
        } else if (_distribution == Distribution.COMMUNITY) {
            communityShare -= _amount;
        } else if (_distribution == Distribution.ECOSYSTEM) {
            ecosystemShare -= _amount;
        } else if (_distribution == Distribution.LIQUIDITY) {
            liquidityShare -= _amount;
        }

        town.safeTransfer(_to, _amount);
        emit Distributed(uint8(_distribution), _to, _amount);
    }
}
