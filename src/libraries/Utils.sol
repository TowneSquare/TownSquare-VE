// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library Utils {
    using Math for uint256;

    uint256 internal constant ONE_18_DP = 1e18;

    /// @dev Calculates the asset amount received from withdrawing.
    /// @param fAmount The amount of fAsset.
    /// @param depositInterestIndexAtT 18dp - The deposit interest index at time T.
    /// @return The corresponding underling asset amount.
    function toUnderlingAmount(
        uint256 fAmount,
        uint256 depositInterestIndexAtT
    ) internal pure returns (uint256) {
        return fAmount.mulDiv(depositInterestIndexAtT, ONE_18_DP);
    }
}
