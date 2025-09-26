// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccountManager {
    function isAddressRegisteredToAccount(
        bytes32 accountId,
        uint16 chainId,
        bytes32 addr
    ) external view returns (bool);
}
