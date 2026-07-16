# VotingEscrow

veNFT implementation that escrows TOWN tokens as ERC-721 NFTs. Voting power depends on amount locked and remaining lock duration.

---

## Lock Types

### Normal Lock

- Has an `end` timestamp (1 week minimum, 4 years maximum)
- Voting power decays linearly to 0 at expiry
- Formula: `votingPower = amount / MAXTIME * (end - now)`
- Exit: wait for `end`, then call `withdraw` to get TOWN back immediately

### Permanent Lock

- No expiry (`end = 0`)
- Voting power is flat at `amount` forever — no decay
- `increaseAmount` always gives full 1:1 voting power
- Only permanent locks can delegate voting power
- Exit: call `unlockPermanent` → converts to a fresh 4-year timed lock → wait → `withdraw`

---

## Locking Positions

Each `createLock` call mints a **new ERC-721 NFT** (separate position). A user can hold multiple NFTs with different amounts and unlock times. Positions can be aggregated, split, or merged.

---

## Functions

### Any User

| Function | What it does |
|---|---|
| `createLock(value, lockDuration)` | Mints a new veNFT, locks TOWN for chosen duration (1 week → 4 years) |
| `checkpoint()` | Manually triggers a global checkpoint, no position required |
| `setApprovalForAll(operator, bool)` | Grants/revokes an operator to manage all your NFTs |

---

### Approved / Owner of the tokenId

| Function | What it does | Extra conditions |
|---|---|---|
| `depositFor(tokenId, value)` | Adds tokens to an existing position | MANAGED type only callable by `distributor` |
| `increaseAmount(tokenId, value)` | Adds more TOWN to a lock, same `end` | Lock must not be expired |
| `increaseUnlockTime(tokenId, duration)` | Extends the unlock time | NORMAL type only, not permanent, not expired |
| `withdraw(tokenId)` | Burns NFT and returns TOWN | NORMAL type, not voted, lock must be expired |
| `lockPermanent(tokenId)` | Converts timed lock to permanent | NORMAL type, not expired, not already permanent |
| `unlockPermanent(tokenId)` | Converts permanent back to a fresh 4-year timed lock | NORMAL type, must not have active votes |
| `merge(from, to)` | Burns `from`, adds its balance into `to` | Both NORMAL, `from` not voted, `to` not expired |
| `split(from, amount)` | Burns `from`, creates two new NFTs with same `end` | NORMAL, not voted, `canSplit` permission required |
| `approve(address, tokenId)` | Approves one address for one NFT | — |
| `transferFrom(from, to, tokenId)` | Transfers NFT | Not LOCKED escrow type |
| `safeTransferFrom(from, to, tokenId)` | Safe transfer with ERC721 receiver check | Not LOCKED escrow type |
| `delegate(delegator, delegatee)` | Delegates voting power to another tokenId | Permanent lock only |
| `delegateBySig(...)` | Same as delegate but via EIP-712 signature | Permanent lock only |

---

### Protocol-Gated

| Function | Caller | What it does |
|---|---|---|
| `toggleSplit(address, bool)` | `team` | Grants/revokes split permission for an address or `address(0)` for everyone |
| `setTeam(address)` | `team` | Transfers team role |
| `setArtProxy(address)` | `team` | Sets the NFT art renderer |
| `setVoterAndDistributor(voter, distributor)` | `voter` | Updates voter and distributor addresses |
| `voting(tokenId, bool)` | `voter` | Marks a tokenId as having voted or not |
| `setAllowedManager(address)` | `governor` | Sets who can create managed locks |
| `setManagedState(mTokenId, bool)` | `governor` or `emergencyCouncil` | Activates/deactivates a managed NFT |
| `createManagedLockFor(address)` | `allowedManager` or `governor` | Creates a managed veNFT that other NFTs can deposit into |
| `depositManaged(tokenId, mTokenId)` | `voter` | Deposits a NORMAL NFT into a managed NFT |
| `withdrawManaged(tokenId)` | `voter` | Withdraws a NORMAL NFT from a managed NFT, claims accrued rewards |

---

## Position Management

### `increaseAmount` — adds tokens, preserves lock time

Voting power gain depends on how much time is left on the lock. The later into the lock period you add, the less voting power per token you receive.

```
Example (MAXTIME = 4 years):
  Original: 100 TOWN locked, 2 years remaining → 50 veTOWN
  increaseAmount(+100 TOWN)
  New power: 200 / 4yr * 2yr = 100 veTOWN  (+50 gained)

  vs. a fresh createLock(100 TOWN, 4yr) = 100 veTOWN
```

For permanent locks, `increaseAmount` always gives full 1:1 power regardless of when it is called.

### `merge` — combines two positions into one

Burns the `from` NFT and folds its balance into `to`. The resulting unlock time is whichever `end` is later between the two.

### `split` — divides one position into two

Both new NFTs inherit the **exact same `end`** (and `isPermanent`) from the original. Total voting power is perfectly conserved — it is only redistributed.

```
Example:
  Original: 1000 TOWN, 2 years remaining → 500 veTOWN
  split(_from, 300)
  tokenId1: 700 TOWN, 2yr → 350 veTOWN
  tokenId2: 300 TOWN, 2yr → 150 veTOWN
  Total:                     500 veTOWN  (unchanged)
```

Split requires `canSplit[owner]` or `canSplit[address(0)]` to be set by `team`.

---

## Normal vs Permanent Lock

| | Normal Lock | Permanent Lock |
|---|---|---|
| Expiry | Has `end` timestamp | `end = 0`, never expires |
| Voting power | Decays linearly to 0 | Flat 1:1, no decay |
| `increaseAmount` bonus | Less power per token as time passes | Always full 1:1 |
| Can delegate | No | Yes |
| Can deposit into managed NFT | Yes | Yes (clears delegation first) |
| Can split | Yes | Yes (children inherit `isPermanent`) |
| Exit | Wait for `end` → `withdraw` | `unlockPermanent` → wait 4 years → `withdraw` |

---

## Permission Summary

```
Regular user   →  createLock, checkpoint, setApprovalForAll
Approved/Owner →  increaseAmount, increaseUnlockTime, withdraw, merge,
                  split, lockPermanent, unlockPermanent, delegate, transfer
split          →  additionally needs canSplit[owner] or canSplit[address(0)]
delegate       →  additionally needs isPermanent == true
team           →  toggleSplit, setTeam, setArtProxy
voter          →  voting, setVoterAndDistributor, depositManaged, withdrawManaged
governor       →  setAllowedManager, setManagedState, createManagedLockFor
```
