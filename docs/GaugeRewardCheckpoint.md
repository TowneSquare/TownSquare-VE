# Gauge Reward Checkpoint Issue

## Summary

The `Gauge` contract distributes TOWN emissions to users proportional to their
collateral deposits and borrows in the lending pool. Because user balances are
read **live from the lending pool at claim time** rather than tracked inside the
gauge, there is no automatic checkpoint when a user changes their collateral
position. This allows extra collateral deposited mid-epoch to retroactively earn
rewards for the full period since the user's last checkpoint.

---

## Background

The `Gauge` uses the standard Synthetix reward-per-token accumulator pattern:

```
earned = currentBalance × (rewardPerToken_now − rewardPerTokenPaid_last) / PRECISION
       + accruedRewards
```

In a standard staking gauge, `currentBalance` is the amount the user has staked
**inside the gauge contract**, so `_updateRewards` is called automatically on
every `stake` and `withdraw`. Here, collateral lives in the lending pool and the
gauge fetches it live via `ILoanManager.getUserLoan()`. There is no hook from
the pool into the gauge when a user's position changes.

---

## Root Cause

`_updateRewards` — which snapshots accrued rewards and sets
`userCollateralRewardPerTokenPaid` — is only triggered when a user calls
`getReward`. It is **never triggered automatically** when the user deposits or
withdraws collateral in the lending pool.

```solidity
// Gauge.sol — earned() reads balance live at call time
uint256 collateralBalance = ILoanManager(loanManager)
    .getUserLoan(_accountLoans[i])
    .collateral[i].balance;   // current balance, not historical

uint256 collateralReward =
    (Utils.toUnderlyingAmount(collateralBalance, depositInterestIndex) *
        (collateralRewardPerToken() - userCollateralRewardPerTokenPaid[account]))
    / PRECISION
    + collateralRewards[account];
```

The gap between `rewardPerToken_now` and `userCollateralRewardPerTokenPaid` covers
the entire period since the user's last `getReward` call. If the user's balance
has grown since then, the larger current balance is applied to that full gap.

---

## Attack Scenario

```
Epoch start  (T = 0)
    Reward notified: 1,000,000 TOWN dripping over 14 days
    Alice's collateral: 1,000 TOWN
    Total collateral: 100,000 TOWN  →  Alice's fair share ≈ 1% = 10,000 TOWN

T = 13 days  (1 day before epoch ends)
    Alice deposits 99,000 extra collateral → total balance = 100,000 TOWN
    Alice does NOT call getReward first

T = 14 days  (epoch end, Alice calls getReward)
    earned() reads currentBalance = 100,000 TOWN
    userCollateralRewardPerTokenPaid = 0  (never updated this epoch)
    earned ≈ 100,000 × (rewardPerToken_full_epoch - 0) / PRECISION
           ≈ ~50% of all epoch rewards
```

Alice holds 1% of collateral for 13 days and 50% for 1 day, but claims ~50%
of the epoch's rewards instead of the fair ~1.6%.

---

## Impact

| Severity | Area |
|----------|------|
| High | Reward distribution fairness |
| Medium | Protocol emissions can be drained by late large depositors |
| Low | Honest early depositors receive less than their fair share |

---

## Proposed Solutions

### Option 1 — Lending Pool Callback *(Recommended for production)*

The lending pool calls `gauge.checkpoint(user)` on every collateral
deposit and withdrawal. This auto-snapshots rewards before any balance change.

```solidity
// Gauge.sol
function checkpoint(
    address _account,
    bytes32[] calldata _accountLoans,
    uint16 _chainId
) external {
    _updateRewards(_account, _accountLoans, _chainId);
}

// Lending pool — on deposit/withdraw
IGauge(gauge).checkpoint(msg.sender, userLoans, chainId);
```

**Pros:** Fully automatic, zero user action required, ungameable.  
**Cons:** Tight coupling between pool and gauge; if multiple gauges exist per
pool, each must be notified.

---

### Option 2 — Public `checkpoint()` + Snapshotted Balance Cap *(Quick fix)*

Expose `checkpoint()` publicly and cap `earned()` to the balance recorded at
the last checkpoint. Users or keepers call this before depositing extra
collateral.

```solidity
mapping(address => uint256) public snapshotCollateral;
mapping(address => uint256) public snapshotBorrow;

function checkpoint(
    address _account,
    bytes32[] calldata _accountLoans,
    uint16 _chainId
) external {
    _updateRewards(_account, _accountLoans, _chainId);
    (uint256 col, uint256 bor) = _getBalances(_account, _accountLoans, _chainId);
    snapshotCollateral[_account] = col;
    snapshotBorrow[_account] = bor;
}

// In earned() — cap effective balance
uint256 effectiveCollateral = Math.min(
    Utils.toUnderlyingAmount(collateralBalance, depositInterestIndex),
    snapshotCollateral[_account]
);
```

**Pros:** No pool coupling, implementable immediately.  
**Cons:** Relies on users or keepers to call `checkpoint()` at the right time;
does not fully prevent gaming if the call is missed.

---

### Option 3 — Epoch-Start Snapshot *(Clean fairness boundary)*

Record a timestamp when rewards are notified. At claim time, read each user's
balance **at that timestamp** using historical pool data rather than the current
balance.

```solidity
uint256 public epochStartTimestamp;

function notifyRewardAmount(uint256 _amount) external {
    epochStartTimestamp = block.timestamp;
    _notifyRewardAmount(msg.sender, _amount);
}

// In earned() — use historical balance instead of current
uint256 collateralBalance = IPool(stakingToken)
    .getDepositDataAt(account, epochStartTimestamp)
    .balance;
```

**Pros:** Perfectly fair — all users evaluated on the same snapshot; late
deposits have zero effect on the current epoch.  
**Cons:** Requires the lending pool to support historical balance queries.

---

### Option 4 — Time-Weighted Average Balance *(Most rigorous)*

Track a cumulative balance-time product for each user. Rewards are proportional
to the average balance held over the epoch, not the balance at any single point.

```solidity
mapping(address => uint256) public lastBalanceTimestamp;
mapping(address => uint256) public cumulativeBalance;

function _updateTWAB(address account, uint256 currentBalance) internal {
    uint256 elapsed = block.timestamp - lastBalanceTimestamp[account];
    cumulativeBalance[account] += currentBalance * elapsed;
    lastBalanceTimestamp[account] = block.timestamp;
}

// In earned() — use time-weighted average
uint256 avgBalance = cumulativeBalance[account] / Constants.EPOCH;
```

**Pros:** Mathematically correct — a late large deposit only earns proportional
to the time it was held.  
**Cons:** Most complex to implement; still requires a trigger whenever the
user's balance changes.

---

## Recommendation

| Option | Effort | Gaming-proof | Pool coupling |
|--------|--------|--------------|---------------|
| 1 — Pool callback | Medium | ✅ Fully | High |
| 2 — Public checkpoint | Low | ⚠️ Partial | None |
| 3 — Epoch snapshot | Medium | ✅ Fully | Medium |
| 4 — TWAB | High | ✅ Fully | Medium |

**Immediate:** Implement Option 2 (`checkpoint()` + balance cap) as a short-term
fix — it is low-effort and reduces the attack surface significantly.

**Production:** Implement Option 1 (pool callback) once the lending pool
integration is finalised. This is the only approach that requires zero user
action and is fully ungameable.

---

## Affected Files

| File | Lines |
|------|-------|
| `src/gauges/Gauge.sol` | `earned()` L188–251, `_updateRewards()` L293–317 |
| `src/interfaces/IGauge.sol` | `getReward`, `earned` signatures |
