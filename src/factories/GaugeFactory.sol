// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IGaugeFactory} from "../interfaces/factories/IGaugeFactory.sol";
import {Gauge} from "../gauges/Gauge.sol";

contract GaugeFactory is IGaugeFactory {
    /// @inheritdoc IGaugeFactory
    address public notifyAdmin;

    address public accountManager;

    constructor(address _accountManager) {
        notifyAdmin = msg.sender;
        accountManager = _accountManager;
    }

    /// @inheritdoc IGaugeFactory
    function setNotifyAdmin(address _admin) external {
        if (notifyAdmin != msg.sender) revert NotAuthorized();
        if (_admin == address(0)) revert ZeroAddress();
        notifyAdmin = _admin;
        emit SetNotifyAdmin(_admin);
    }

    function setAccountManger(address _accountManger) external {
        if (notifyAdmin != msg.sender) revert NotAuthorized();
        if (_accountManger == address(0)) revert ZeroAddress();
        accountManager = _accountManager;
        emit SetAccountManager(_accountManger);
    }

    function createGauge(
        address _forwarder,
        address _pool,
        address _rewardToken,
        bool isPool
    ) external returns (address gauge) {
        gauge = address(
            new Gauge(
                _forwarder,
                _pool,
                _rewardToken,
                msg.sender,
                accountManager,
                isPool
            )
        );
    }
}
