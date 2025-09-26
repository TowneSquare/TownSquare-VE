// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

library Messages {
    function convertEVMAddressToGenericAddress(
        address addr
    ) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function convertGenericAddressToEVMAddress(
        bytes32 addr
    ) internal pure returns (address) {
        return address(uint160(uint256(addr)));
    }
}
