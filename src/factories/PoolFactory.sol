// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IPoolFactory} from "../interfaces/factories/IPoolFactory.sol";

import {ILoanController} from "../../src/interfaces/ILoanController.sol";

contract PoolFactory is IPoolFactory {
    /// @inheritdoc IPoolFactory
    address public loanController;

    // mapping(address => uint256) public customFee; // override for custom fees

    constructor(address _loanController) {
        loanController = _loanController;
    }

    /// @inheritdoc IPoolFactory
    function isPool(uint8 poolId) external view returns (bool) {
        return ILoanController(loanController).isPoolAdded(poolId);
    }

    function getPool(uint8 poolId) external view returns (address) {
        return ILoanController(loanController).getPool(poolId);
    }
}
