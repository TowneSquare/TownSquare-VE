// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAccountManager {
    function isAddressRegisteredToAccount(
        bytes32 accountId,
        uint16 chainId,
        bytes32 addr
    ) external view returns (bool);

    function getAccountIdOfAddressOnChain(
        bytes32 addr,
        uint16 chainId
    ) external view returns (bytes32);
}
