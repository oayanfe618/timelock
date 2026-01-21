```markdown
# Time-Lock Savings DAO

A comprehensive Clarity smart contract implementing a decentralized time-locked savings vault with interest-style rewards, emergency withdrawal penalties, DAO governance, and user reputation tracking on the Stacks blockchain.

## Features

###  Time-Locked Savings Vault
- **Lock STX tokens** for a specified duration to earn rewards
- **Flexible lock periods** - choose your commitment length
- **Secure storage** - funds held in contract escrow during lock period

###  Interest-Style Reward Distribution
- **Automatic rewards** - 5% default reward rate on matured locks
- **Penalty-free withdrawals** - full amount + rewards after unlock block
- **Emergency withdrawals** - withdraw early with 10% penalty (default)

###  DAO Governance
- **Community proposals** - vote on parameter changes (reward rate, penalty rate)
- **Democratic voting** - one vote per participant per proposal
- **Time-locked execution** - proposals finalize after voting period ends
- **Yes/No voting** - simple majority determines outcome

### User Reputation System
- **Reputation points** - earned by completing lock periods
- **Long-term incentives** - encourages sustained participation
- **Compound rewards** - boost reputation through active engagement

###  Advanced Features
- **Lock extension** - extend your lock period anytime (cannot shorten)
- **Reward compounding** - re-lock earned rewards for additional gains
- **Pool donations** - external contributions increase available rewards
- **Parameter flexibility** - community-governed risk/reward balance

## Contract Architecture

### Data Structures

#### Savings Map
```
{
  amount: uint,           // STX locked amount
  unlock-block: uint      // Block height when unlock is available
}
```

#### Proposals Map
```
{
  proposer: principal,    // Who created the proposal
  new-reward: uint,       // Proposed new reward rate
  new-penalty: uint,      // Proposed new penalty rate
  end-block: uint,        // Voting period end
  yes: uint,              // Yes votes count
  no: uint,               // No votes count
  executed: bool          // Execution status
}
```

#### Reputation Map
```
principal → uint         // User reputation points
```

## Function Reference

### Savings Operations

#### `lock-savings(amount, duration)`
Lock STX tokens for a specified duration (in blocks).
- **Parameters**: 
  - `amount`: STX amount to lock
  - `duration`: Lock duration in blocks
- **Returns**: `(ok true)` or error
- **Example**: Lock 1000 STX for 144 blocks (≈24 hours)

#### `withdraw()`
Withdraw locked savings with rewards or penalties.
- **Returns**: `(ok true)` with STX transferred, or error
- **On maturity**: Receives `amount + reward`
- **Early withdrawal**: Receives `amount - penalty`

#### `extend-lock(extra-blocks)`
Extend your lock period (irreversible).
- **Parameters**: 
  - `extra-blocks`: Additional blocks to lock
- **Returns**: `(ok true)` or error
- **Note**: Cannot shorten lock period

#### `compound()`
Re-lock earned rewards for additional gains (only after maturity).
- **Returns**: `(ok true)` or error
- **Action**: Resets lock to 144 blocks from now with new principal
- **Benefit**: Earns reputation points on re-lock

### DAO Governance

#### `create-proposal(new-reward, new-penalty, duration)`
Create a governance proposal to change contract parameters.
- **Parameters**:
  - `new-reward`: Proposed reward rate percentage
  - `new-penalty`: Proposed penalty rate percentage
  - `duration`: Voting period in blocks
- **Returns**: `(ok proposal-id)` or error

#### `vote(proposal-id, support)`
Vote on an active governance proposal.
- **Parameters**:
  - `proposal-id`: ID of the proposal
  - `support`: `true` for yes, `false` for no
- **Returns**: `(ok true)` or error
- **Restriction**: One vote per user per proposal

#### `execute-proposal(proposal-id)`
Execute a passed proposal to update contract parameters.
- **Parameters**: 
  - `proposal-id`: ID of the proposal to execute
- **Returns**: `(ok true)` or error
- **Requirements**:
  - Voting period must be over
  - Yes votes must exceed no votes
  - Proposal not already executed

### Pool Management

#### `donate-to-pool(amount)`
Contribute STX to increase available rewards.
- **Parameters**: 
  - `amount`: STX to donate
- **Returns**: `(ok true)` or error
- **Benefit**: Increases reward pool for all users

### Read-Only Functions

#### `get-savings(user)`
Check a user's locked savings status.
- **Returns**: `{amount: uint, unlock-block: uint}` or `none`

#### `get-reputation(user)`
Check a user's reputation points.
- **Returns**: Reputation score (uint)

#### `get-parameters()`
Check current contract parameters.
- **Returns**: 
```
{
  reward-rate: uint,
  penalty-rate: uint,
  pool-balance: uint
}
```

## Parameter Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `reward-rate` | 5% | Percentage reward on matured locks |
| `penalty-rate` | 10% | Percentage penalty on early withdrawals |
| `pool-balance` | Dynamic | Total STX available in reward pool |

## Error Codes

| Code | Name | Meaning |
|------|------|---------|
| `u100` | ERR-AUTH | Authorization/authentication failed |
| `u101` | ERR-STATE | Invalid state for operation |
| `u102` | ERR-BALANCE | Insufficient balance |
| `u103` | ERR-NOT-FOUND | User/resource not found |

## Usage Examples

### Example 1: Basic Savings Lock
```clarity
;; Lock 1000 STX for 144 blocks (~24 hours on Stacks)
(contract-call? timelock lock-savings u1000 u144)

;; After 144 blocks, withdraw with 5% reward
;; Receive: 1050 STX (1000 + 50 reward)
(contract-call? timelock withdraw)
```

### Example 2: Early Withdrawal with Penalty
```clarity
;; Lock 1000 STX for 1440 blocks (10 days)
(contract-call? timelock lock-savings u1000 u1440)

;; Withdraw after 100 blocks (before maturity)
;; Receive: 900 STX (1000 - 100 penalty)
(contract-call? timelock withdraw)
```

### Example 3: DAO Governance
```clarity
;; Propose changing reward rate to 7% and penalty to 12%
(contract-call? timelock create-proposal u7 u12 u288)

;; Vote yes on proposal #1
(contract-call? timelock vote u1 true)

;; After voting period, execute proposal
(contract-call? timelock execute-proposal u1)
```

### Example 4: Compound Rewards
```clarity
;; Lock and mature (as shown in Example 1)

;; After maturity, compound your rewards
;; Your 1050 STX becomes new principal with 144 block lock
(contract-call? timelock compound)

;; Gain additional 52.5 STX reward (5% of 1050)
```

## Security Considerations

 **Implemented safeguards:**
- STX transferred via secure `stx-transfer?` calls
- Duplicate voting prevention via votes map
- State validation before operations
- Principal-based access control

 **Data validation warnings:**
- Input parameters not independently validated (rely on caller)
- Consider adding minimum lock duration checks
- Consider adding maximum penalty/reward boundaries

## Deployment

### Prerequisites
- Clarinet environment setup
- Stacks blockchain access (testnet or mainnet)
- STX tokens for testing

### Deploy to Testnet
```bash
clarinet contract deploy timelock --network testnet
```

### Deploy to Mainnet
```bash
clarinet contract deploy timelock --network mainnet
```

## Testing

Run the test suite:
```bash
clarinet test
```

## License

MIT License - See LICENSE file for details

## Support

For issues, questions, or feature requests, please open an issue in the repository.

---

**Clarity Version**: 2.0+  
**Contract Status**: ✅ Production Ready
