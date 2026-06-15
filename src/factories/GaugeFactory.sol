// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IGaugeFactory} from "../interfaces/factories/IGaugeFactory.sol";
import {Gauge} from "../gauges/Gauge.sol";

contract GaugeFactory is IGaugeFactory {
    /// @inheritdoc IGaugeFactory
    address public notifyAdmin;

    address public accountManager;

    address public loanManager;

    constructor(address _accountManager, address _loanManager) {
        notifyAdmin = msg.sender;
        accountManager = _accountManager;
        loanManager = _loanManager;
    }

    /// @inheritdoc IGaugeFactory
    function setNotifyAdmin(address _admin) external {
        if (notifyAdmin != msg.sender) revert NotAuthorized();
        if (_admin == address(0)) revert ZeroAddress();
        notifyAdmin = _admin;
        emit SetNotifyAdmin(_admin);
    }

    function setAccountManager(address _accountManager) external {
        if (notifyAdmin != msg.sender) revert NotAuthorized();
        if (_accountManager == address(0)) revert ZeroAddress();
        accountManager = _accountManager;
        emit SetAccountManager(_accountManager);
    }

    function setLoanManager(address _loanManager) external {
        if (notifyAdmin != msg.sender) revert NotAuthorized();
        if (_loanManager == address(0)) revert ZeroAddress();
        loanManager = _loanManager;
        emit SetLoanManager(_loanManager);
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
                loanManager,
                isPool
            )
        );
    }
}
