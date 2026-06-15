// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITown} from "./ITown.sol";

interface ITokenMinter {
    enum Distribution {
        INVESTOR,
        TEAM,
        FOUNDATION,
        COMMUNITY,
        ECOSYSTEM,
        LIQUIDITY
    }

    error NotTeam();
    error ZeroAddress();
    error ZeroAmount();
    error NotPendingTeam();
    error InvalidTotalPercent();

    event AcceptTeam(address indexed newTeam);
    event Distributed(
        uint8 indexed distribution,
        address indexed to,
        uint256 amount
    );

    /// @notice The TOWN token
    function town() external view returns (ITown);

    /// @notice Denominator for share calculations (basis points)
    function MAX_BPS() external view returns (uint256);

    /// @notice Remaining investor allocation
    function investorShare() external view returns (uint256);

    /// @notice Remaining team allocation
    function teamShare() external view returns (uint256);

    /// @notice Remaining foundation allocation
    function foundationShare() external view returns (uint256);

    /// @notice Remaining community allocation
    function communityShare() external view returns (uint256);

    /// @notice Remaining ecosystem allocation
    function ecosystemShare() external view returns (uint256);

    /// @notice Remaining liquidity allocation
    function liquidityShare() external view returns (uint256);

    /// @notice Address authorised to call distribute
    function team() external view returns (address);

    /// @notice Pending team address awaiting acceptance
    function pendingTeam() external view returns (address);

    /// @notice Initiates a team address transfer
    function setTeam(address _team) external;

    /// @notice Completes a team address transfer
    function acceptTeam() external;

    /// @notice Transfers tokens from a distribution bucket to a recipient
    /// @param _distribution The bucket to draw from
    /// @param _amount       Amount to transfer
    /// @param _to           Recipient address
    function distribute(
        Distribution _distribution,
        uint256 _amount,
        address _to
    ) external;
}
