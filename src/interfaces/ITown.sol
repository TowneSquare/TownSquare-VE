// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITown is IERC20 {
    error NotMinter();
    error NotOwner();

    /// @notice Address of TokenMinter.sol
    function tokenMinter() external view returns (address);
}
