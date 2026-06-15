// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITown} from "./ITown.sol";
import {IVoter} from "./IVoter.sol";
import {IVotingEscrow} from "./IVotingEscrow.sol";
import {IRewardsDistributor} from "./IRewardsDistributor.sol";

interface IMinter {
    error NotTeam();
    error ZeroAddress();
    error ZeroAmount();
    error NotPendingTeam();
    error NotEnoughTown();

    event Mint(address indexed sender, uint256 emission);
    event AcceptTeam(address indexed newTeam);
    event EmissionAmountSet(uint256 emissionAmount);

    /// @notice The TOWN token
    function town() external view returns (ITown);

    /// @notice The Voter contract
    function voter() external view returns (IVoter);

    /// @notice The VotingEscrow contract
    function ve() external view returns (IVotingEscrow);

    /// @notice The RewardsDistributor contract
    function rewardsDistributor() external view returns (IRewardsDistributor);

    /// @notice Per-epoch emission amount
    function emissions() external view returns (uint256);

    /// @notice Timestamp of the start of the current epoch
    function activePeriod() external view returns (uint256);

    /// @notice Address authorised to manage emission parameters
    function team() external view returns (address);

    /// @notice Pending team address awaiting acceptance
    function pendingTeam() external view returns (address);

    /// @notice Initiates a team address transfer
    function setTeam(address _team) external;

    /// @notice Completes a team address transfer
    function acceptTeam() external;

    /// @notice Sets the Voter contract address
    function setVoter(address _voter) external;

    /// @notice Sets the VotingEscrow contract address
    function setVe(address _ve) external;

    /// @notice Sets the RewardsDistributor contract address
    function setRewardsDistributor(address _rewardsDistributor) external;

    /// @notice Sets the per-epoch emission amount
    function setEmissionAmount(uint256 _emission) external;

    /// @notice Calculates the rebase growth for an epoch
    ///         Formula: emission * (veSupply / townSupply)^3 / 2
    function calculateGrowth(uint256 _minted) external view returns (uint256);

    /// @notice Processes emissions and rebases. Callable once per epoch.
    /// @return _period Start of the current epoch
    function updatePeriod() external returns (uint256 _period);
}
