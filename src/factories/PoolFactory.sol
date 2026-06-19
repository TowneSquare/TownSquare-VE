// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IPoolFactory} from "../interfaces/factories/IPoolFactory.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract PoolFactory is IPoolFactory {
    /// @inheritdoc IPoolFactory
    address public immutable implementation;

    /// @inheritdoc IPoolFactory
    bool public isPaused;
    /// @inheritdoc IPoolFactory
    address public pauser;

    /// @inheritdoc IPoolFactory
    // uint256 public stableFee;
    /// @inheritdoc IPoolFactory
    // uint256 public volatileFee;
    /// @inheritdoc IPoolFactory
    uint256 public constant MAX_FEE = 300; // 3%
    /// @inheritdoc IPoolFactory
    uint256 public constant ZERO_FEE_INDICATOR = 420;
    /// @inheritdoc IPoolFactory
    address public feeManager;
    /// @inheritdoc IPoolFactory
    address public poolAdmin;

    mapping(address => mapping(uint8 => address)) private _getPool;
    address[] internal _allPools;
    /// @dev simplified check if its a pool, given that `stable` flag might not be available in peripherals
    mapping(address => bool) private _isPool;

    // mapping(address => uint256) public customFee; // override for custom fees

    error PoolAlreadyExist();

    constructor(address _implementation) {
        implementation = _implementation;
        poolAdmin = msg.sender;
        pauser = msg.sender;
        feeManager = msg.sender;
        isPaused = false;
        // stableFee = 5; // 0.05%
        // volatileFee = 30; // 0.3%
    }

    /// @inheritdoc IPoolFactory
    function allPools(uint256 index) external view returns (address) {
        return _allPools[index];
    }

    /// @inheritdoc IPoolFactory
    function allPools() external view returns (address[] memory) {
        return _allPools;
    }

    /// @inheritdoc IPoolFactory
    function allPoolsLength() external view returns (uint256) {
        return _allPools.length;
    }

    /// @inheritdoc IPoolFactory
    // function getPool(
    //     address tokenA,
    //     address tokenB,
    //     uint24 fee
    // ) external view returns (address) {
    //     return
    //         fee > 1
    //             ? address(0)
    //             : fee == 1
    //                 ? _getPool[tokenA][tokenB][true]
    //                 : _getPool[tokenA][tokenB][false];
    // }

    /// @inheritdoc IPoolFactory
    function getPool(
        address token,
        uint8 poolId
    ) external view returns (address) {
        return _getPool[token][poolId];
    }

    /// @inheritdoc IPoolFactory
    function isPool(address pool) external view returns (bool) {
        return _isPool[pool];
    }

    /// @inheritdoc IPoolFactory
    function setPoolAdmin(address _poolAdmin) external {
        if (msg.sender != poolAdmin) revert NotPoolAdmin();
        if (_poolAdmin == address(0)) revert ZeroAddress();
        poolAdmin = _poolAdmin;
        emit SetPoolAdmin(_poolAdmin);
    }

    /// @inheritdoc IPoolFactory
    function setPauser(address _pauser) external {
        if (msg.sender != pauser) revert NotPauser();
        if (_pauser == address(0)) revert ZeroAddress();
        pauser = _pauser;
        emit SetPauser(_pauser);
    }

    /// @inheritdoc IPoolFactory
    function setPauseState(bool _state) external {
        if (msg.sender != pauser) revert NotPauser();
        isPaused = _state;
        emit SetPauseState(_state);
    }

    /// @inheritdoc IPoolFactory
    function setFeeManager(address _feeManager) external {
        if (msg.sender != feeManager) revert NotFeeManager();
        if (_feeManager == address(0)) revert ZeroAddress();
        feeManager = _feeManager;
        emit SetFeeManager(_feeManager);
    }

    /// @inheritdoc IPoolFactory
    // function setFee(bool _stable, uint256 _fee) external {
    //     if (msg.sender != feeManager) revert NotFeeManager();
    //     if (_fee > MAX_FEE) revert FeeTooHigh();
    //     if (_fee == 0) revert ZeroFee();
    //     if (_stable) {
    //         stableFee = _fee;
    //     } else {
    //         volatileFee = _fee;
    //     }
    // }

    /// @inheritdoc IPoolFactory
    // function setCustomFee(address pool, uint256 fee) external {
    //     if (msg.sender != feeManager) revert NotFeeManager();
    //     if (fee > MAX_FEE && fee != ZERO_FEE_INDICATOR) revert FeeTooHigh();
    //     if (!_isPool[pool]) revert InvalidPool();

    //     customFee[pool] = fee;
    //     emit SetCustomFee(pool, fee);
    // }

    /// @inheritdoc IPoolFactory
    // function getFee(address pool, bool _stable) public view returns (uint256) {
    //     uint256 fee = customFee[pool];
    //     return
    //         fee == ZERO_FEE_INDICATOR
    //             ? 0
    //             : fee != 0
    //                 ? fee
    //                 : _stable
    //                     ? stableFee
    //                     : volatileFee;
    // }

    /// @inheritdoc IPoolFactory
    // function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool) {
    //     if (fee > 1) revert FeeInvalid();
    //     bool stable = fee == 1;
    //     return createPool(tokenA, tokenB, stable);
    // }

    /// @inheritdoc IPoolFactory
    function createPool(
        address pool,
        address token,
        uint8 poolId
    ) public returns (address) {
        if (token == address(0)) revert ZeroAddress();
        if (pool == address(0)) revert ZeroAddress();
        if (_getPool[token][poolId] != address(0)) revert PoolAlreadyExist();
        _getPool[token][poolId] = pool;
        _allPools.push(pool);
        _isPool[pool] = true;

        return pool;
    }
}
