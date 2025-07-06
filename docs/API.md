# API Documentation

## Cross-Chain Liquidity Aggregator API Reference

This document provides detailed information about all available functions in the Cross-Chain Liquidity Aggregator smart contract.

## Table of Contents

- [Read-Only Functions](#read-only-functions)
- [Public Functions](#public-functions)
- [Admin Functions](#admin-functions)
- [Error Codes](#error-codes)
- [Data Structures](#data-structures)

## Read-Only Functions

### `get-pool(pool-id: uint)`

Returns detailed information about a specific liquidity pool.

**Parameters:**
- `pool-id`: Unique identifier of the pool

**Returns:**
```clarity
(optional {
  token-a: principal,
  token-b: principal,
  reserve-a: uint,
  reserve-b: uint,
  total-supply: uint,
  fee-rate: uint,
  created-at: uint,
  active: bool
})
```

**Example:**
```clarity
(contract-call? .cross-chain-liquidity-aggregator get-pool u1)
```

### `get-pool-id(token-a: principal, token-b: principal)`

Finds the pool ID for a given token pair.

**Parameters:**
- `token-a`: Principal of the first token
- `token-b`: Principal of the second token

**Returns:**
```clarity
(optional uint)
```

**Example:**
```clarity
(contract-call? .cross-chain-liquidity-aggregator get-pool-id 
  .token-a-contract .token-b-contract)
```

### `get-liquidity-shares(pool-id: uint, provider: principal)`

Returns the liquidity provider token balance for a specific provider in a pool.

**Parameters:**
- `pool-id`: Pool identifier
- `provider`: Address of the liquidity provider

**Returns:**
```clarity
uint
```

### `calculate-swap-output(pool-id: uint, token-in: principal, amount-in: uint)`

Calculates the expected output amount for a token swap, including fees.

**Parameters:**
- `pool-id`: Pool identifier
- `token-in`: Input token contract address
- `amount-in`: Amount of input tokens

**Returns:**
```clarity
(response uint uint)
```

**Formula:**
```
output = (amount-in * (10000 - fee-rate) * reserve-out) / 
         (reserve-in * 10000 + amount-in * (10000 - fee-rate))
```

### `get-protocol-info()`

Returns current protocol configuration and statistics.

**Returns:**
```clarity
{
  protocol-fee: uint,
  fee-recipient: principal,
  paused: bool,
  next-pool-id: uint,
  next-swap-id: uint
}
```

### `get-cross-chain-swap(swap-id: uint)`

Returns information about a cross-chain swap operation.

**Parameters:**
- `swap-id`: Unique identifier of the cross-chain swap

**Returns:**
```clarity
(optional {
  initiator: principal,
  source-token: principal,
  target-token: (string-ascii 64),
  source-amount: uint,
  target-amount: uint,
  target-chain: (string-ascii 32),
  target-address: (string-ascii 64),
  status: (string-ascii 16),
  created-at: uint,
  expires-at: uint
})
```

### `get-pool-stats(pool-id: uint)` 🆕

Returns comprehensive statistics for a liquidity pool.

**Parameters:**
- `pool-id`: Pool identifier

**Returns:**
```clarity
(response {
  pool-id: uint,
  reserve-a: uint,
  reserve-b: uint,
  total-supply: uint,
  k-value: uint,
  price-a-in-b: uint,
  price-b-in-a: uint,
  utilization-rate: uint,
  active: bool,
  fee-rate: uint,
  created-at: uint
} uint)
```

### `calculate-price-impact(pool-id: uint, token-in: principal, amount-in: uint)` 🆕

Calculates the price impact of a potential swap.

**Parameters:**
- `pool-id`: Pool identifier
- `token-in`: Input token contract address
- `amount-in`: Amount of input tokens

**Returns:**
```clarity
(response {
  current-price: uint,
  new-price: uint,
  price-impact: uint,
  amount-out: uint
} uint)
```

### `get-pool-health(pool-id: uint)` 🆕

Returns health metrics for a liquidity pool.

**Parameters:**
- `pool-id`: Pool identifier

**Returns:**
```clarity
(response {
  pool-id: uint,
  balance-ratio: uint,
  liquidity-depth: uint,
  is-balanced: bool,
  min-liquidity-met: bool,
  health-score: uint
} uint)
```

### `get-pool-fees(pool-id: uint)` 🆕

Returns fee statistics for a pool.

**Parameters:**
- `pool-id`: Pool identifier

**Returns:**
```clarity
(response {
  total-fees-a: uint,
  total-fees-b: uint,
  last-updated: uint
} uint)
```

### `get-protocol-fees(token: principal)` 🆕

Returns protocol fees collected for a specific token.

**Parameters:**
- `token`: Token contract address

**Returns:**
```clarity
(response {
  total-collected: uint,
  last-updated: uint
} uint)
```

### `get-pool-analytics(pool-id: uint)` 🆕

Returns comprehensive analytics combining stats, health, and fees.

**Parameters:**
- `pool-id`: Pool identifier

**Returns:**
```clarity
(response {
  basic-stats: {...},
  health-metrics: {...},
  fee-stats: {...}
} uint)
```

### `get-pools-range(start-id: uint, end-id: uint)` 🆕

Returns basic information for multiple pools (pagination support).

**Parameters:**
- `start-id`: Starting pool ID
- `end-id`: Ending pool ID

**Returns:**
```clarity
(response (list 5 (optional {
  pool-id: uint,
  token-a: principal,
  token-b: principal,
  reserve-a: uint,
  reserve-b: uint,
  active: bool,
  fee-rate: uint
})) uint)
```

## Public Functions

### `create-pool(token-a, token-b, initial-a, initial-b, fee-rate)`

Creates a new liquidity pool with initial liquidity provision.

**Parameters:**
- `token-a`: First token contract (SIP-010 trait)
- `token-b`: Second token contract (SIP-010 trait)
- `initial-a`: Initial amount of token A
- `initial-b`: Initial amount of token B
- `fee-rate`: Pool fee rate in basis points (e.g., 300 = 3%)

**Returns:**
```clarity
(response uint uint)
```

**Requirements:**
- Both initial amounts must be > 0
- Fee rate must be ≤ 10000 (100%)
- Token pair must not already exist
- Caller must have sufficient token balances

**Example:**
```clarity
(contract-call? .cross-chain-liquidity-aggregator create-pool
  .token-a .token-b u1000000 u2000000 u300)
```

### `add-liquidity(pool-id, token-a, token-b, amount-a, amount-b, min-liquidity)`

Adds liquidity to an existing pool.

**Parameters:**
- `pool-id`: Target pool identifier
- `token-a`: First token contract
- `token-b`: Second token contract
- `amount-a`: Desired amount of token A
- `amount-b`: Desired amount of token B
- `min-liquidity`: Minimum LP tokens to receive (slippage protection)

**Returns:**
```clarity
(response {
  liquidity-minted: uint,
  amount-a: uint,
  amount-b: uint
} uint)
```

**Note:** The function automatically calculates optimal amounts based on current pool ratio.

### `remove-liquidity(pool-id, token-a, token-b, liquidity-amount, min-amount-a, min-amount-b)`

Removes liquidity from a pool and returns underlying tokens.

**Parameters:**
- `pool-id`: Target pool identifier
- `token-a`: First token contract
- `token-b`: Second token contract
- `liquidity-amount`: Amount of LP tokens to burn
- `min-amount-a`: Minimum token A to receive
- `min-amount-b`: Minimum token B to receive

**Returns:**
```clarity
(response {
  amount-a: uint,
  amount-b: uint
} uint)
```

### `swap-tokens(pool-id, token-in, token-out, amount-in, min-amount-out)`

Performs a token swap within a liquidity pool.

**Parameters:**
- `pool-id`: Target pool identifier
- `token-in`: Input token contract
- `token-out`: Output token contract
- `amount-in`: Amount of input tokens
- `min-amount-out`: Minimum output tokens (slippage protection)

**Returns:**
```clarity
(response {
  amount-in: uint,
  amount-out: uint,
  protocol-fee: uint,
  pool-fee: uint,
  price-impact: uint
} uint)
```

### `initiate-cross-chain-swap(...)`

Initiates a cross-chain swap operation.

**Parameters:**
- `source-token`: Source token contract
- `target-token-address`: Target token address on destination chain
- `target-chain`: Destination blockchain identifier
- `amount`: Amount to swap
- `target-address`: Recipient address on destination chain
- `expires-in-blocks`: Expiration time in blocks

**Returns:**
```clarity
(response uint uint)
```

**Example:**
```clarity
(contract-call? .cross-chain-liquidity-aggregator initiate-cross-chain-swap
  .stx-token
  "0x742d35Cc6634C0532925a3b8D4C9db4C2b7e2b8e"
  "ethereum"
  u1000000
  "0x742d35Cc6634C0532925a3b8D4C9db4C2b7e2b8e"
  u144)
```

## Admin Functions

### `set-protocol-fee(new-fee: uint)`

Updates the protocol fee rate (owner only).

**Parameters:**
- `new-fee`: New fee rate in basis points (0-10000)

**Returns:**
```clarity
(response bool uint)
```

### `set-fee-recipient(new-recipient: principal)`

Changes the protocol fee recipient address (owner only).

**Parameters:**
- `new-recipient`: New fee recipient address

**Returns:**
```clarity
(response bool uint)
```

### `set-paused(pause: bool)`

Pauses or unpauses the protocol (owner only).

**Parameters:**
- `pause`: True to pause, false to unpause

**Returns:**
```clarity
(response bool uint)
```

### `deactivate-pool(pool-id: uint)`

Deactivates a specific pool (owner only).

**Parameters:**
- `pool-id`: Pool to deactivate

**Returns:**
```clarity
(response bool uint)
```

### `emergency-withdraw(token, amount, recipient)`

Emergency withdrawal function (owner only, when paused).

**Parameters:**
- `token`: Token contract to withdraw
- `amount`: Amount to withdraw
- `recipient`: Withdrawal recipient

**Returns:**
```clarity
(response bool uint)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR_UNAUTHORIZED | Caller not authorized for this operation |
| 101 | ERR_INSUFFICIENT_BALANCE | Insufficient token balance |
| 102 | ERR_INSUFFICIENT_LIQUIDITY | Not enough liquidity in pool |
| 103 | ERR_INVALID_AMOUNT | Invalid amount (zero or negative) |
| 104 | ERR_POOL_NOT_FOUND | Pool does not exist |
| 105 | ERR_SLIPPAGE_TOO_HIGH | Slippage exceeds tolerance |
| 106 | ERR_SWAP_EXPIRED | Cross-chain swap has expired |
| 107 | ERR_INVALID_TOKEN | Invalid token for this operation |
| 108 | ERR_PAUSED | Protocol is currently paused |
| 109 | ERR_ALREADY_EXISTS | Pool already exists for token pair |
| 110 | ERR_INVALID_FEE | Fee rate exceeds maximum allowed |

## Data Structures

### Pool Structure
```clarity
{
  token-a: principal,        ;; First token contract
  token-b: principal,        ;; Second token contract
  reserve-a: uint,           ;; Reserve of token A
  reserve-b: uint,           ;; Reserve of token B
  total-supply: uint,        ;; Total LP tokens issued
  fee-rate: uint,            ;; Fee rate in basis points
  created-at: uint,          ;; Block height when created
  active: bool               ;; Pool active status
}
```

### Cross-Chain Swap Structure
```clarity
{
  initiator: principal,           ;; Swap initiator
  source-token: principal,        ;; Source token contract
  target-token: (string-ascii 64), ;; Target token address
  source-amount: uint,            ;; Source amount
  target-amount: uint,            ;; Target amount (set on completion)
  target-chain: (string-ascii 32), ;; Target blockchain
  target-address: (string-ascii 64), ;; Recipient address
  status: (string-ascii 16),      ;; "pending", "completed", "failed"
  created-at: uint,               ;; Creation block height
  expires-at: uint                ;; Expiration block height
}
```

## Usage Examples

### Complete Liquidity Provision Flow

```clarity
;; 1. Create pool
(contract-call? .cross-chain-liquidity-aggregator create-pool
  .token-a .token-b u1000000 u2000000 u300)

;; 2. Add more liquidity
(contract-call? .cross-chain-liquidity-aggregator add-liquidity
  u1 .token-a .token-b u500000 u1000000 u1)

;; 3. Perform swap
(contract-call? .cross-chain-liquidity-aggregator swap-tokens
  u1 .token-a .token-b u100000 u190000)

;; 4. Remove liquidity
(contract-call? .cross-chain-liquidity-aggregator remove-liquidity
  u1 .token-a .token-b u500000 u450000 u900000)
```

This API provides comprehensive functionality for decentralized cross-chain liquidity aggregation with robust error handling and security features.
