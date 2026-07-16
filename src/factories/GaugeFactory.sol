// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IGaugeFactory} from "../interfaces/factories/IGaugeFactory.sol";
import {Gauge} from "../gauges/Gauge.sol";

contract GaugeFactory is IGaugeFactory {
    /// @inheritdoc IGaugeFactory
    address public notifyAdmin;

    constructor() {
        notifyAdmin = msg.sender;
    }

    /// @inheritdoc IGaugeFactory
    function setNotifyAdmin(address _admin) external {
        if (notifyAdmin != msg.sender) revert NotAuthorized();
        if (_admin == address(0)) revert ZeroAddress();
        notifyAdmin = _admin;
        emit SetNotifyAdmin(_admin);
    }

    function createGauge(
        address _rewardToken
    ) external returns (address gauge) {
        gauge = address(new Gauge(_rewardToken, msg.sender));
    }
}
