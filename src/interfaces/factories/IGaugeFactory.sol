// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGaugeFactory {
    error NotAuthorized();
    error ZeroAddress();

    event SetNotifyAdmin(address indexed notifyAdmin);
    event SetAccountManager(address indexed accountManager);
    event SetLoanManager(address indexed loanManager);

    /// @notice Administrator that can call `notifyRewardWithoutClaim` on gauges
    function notifyAdmin() external view returns (address);

    /// @notice Set notifyAdmin value on gauge factory
    /// @param _admin New administrator that will be able to call `notifyRewardWithoutClaim` on gauges.
    function setNotifyAdmin(address _admin) external;

    function setAccountManger(address _accountManager) external;

    function createGauge(
        address _forwarder,
        address _pool,
        address _ve,
        bool isPool
    ) external returns (address);
}
