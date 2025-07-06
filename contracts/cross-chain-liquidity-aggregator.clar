;; Cross-Chain Liquidity Aggregator
;; A comprehensive DeFi protocol for cross-chain liquidity aggregation
;; Supports Bitcoin and Stacks as settlement layers

;; Import SIP-010 trait
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_POOL_NOT_FOUND (err u104))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u105))
(define-constant ERR_SWAP_EXPIRED (err u106))
(define-constant ERR_INVALID_TOKEN (err u107))
(define-constant ERR_PAUSED (err u108))
(define-constant ERR_ALREADY_EXISTS (err u109))
(define-constant ERR_INVALID_FEE (err u110))

;; Protocol constants
(define-constant MAX_FEE u10000) ;; 100% in basis points
(define-constant DEFAULT_PROTOCOL_FEE u30) ;; 0.3% in basis points
(define-constant MIN_LIQUIDITY u1000) ;; Minimum liquidity to prevent division by zero
(define-constant PRECISION u1000000) ;; 6 decimal precision for calculations

;; Data Variables
(define-data-var protocol-fee uint DEFAULT_PROTOCOL_FEE)
(define-data-var fee-recipient principal CONTRACT_OWNER)
(define-data-var paused bool false)
(define-data-var next-pool-id uint u1)

;; Data Maps
;; Pool information: pool-id -> pool data
(define-map pools
  uint
  {
    token-a: principal,
    token-b: principal,
    reserve-a: uint,
    reserve-b: uint,
    total-supply: uint,
    fee-rate: uint,
    created-at: uint,
    active: bool
  }
)

;; Pool lookup by token pair: (token-a, token-b) -> pool-id
(define-map pool-lookup
  { token-a: principal, token-b: principal }
  uint
)

;; Liquidity provider shares: (pool-id, provider) -> shares
(define-map liquidity-shares
  { pool-id: uint, provider: principal }
  uint
)

;; Cross-chain swap tracking: swap-id -> swap data
(define-map cross-chain-swaps
  uint
  {
    initiator: principal,
    source-token: principal,
    target-token: principal,
    source-amount: uint,
    target-amount: uint,
    target-chain: (string-ascii 32),
    target-address: (string-ascii 64),
    status: (string-ascii 16), ;; "pending", "completed", "failed"
    created-at: uint,
    expires-at: uint
  }
)

(define-data-var next-swap-id uint u1)

;; Fee tracking maps
(define-map pool-fees-collected
  uint
  { total-fees-a: uint, total-fees-b: uint, last-updated: uint }
)

(define-map protocol-fees-collected
  principal
  { total-collected: uint, last-updated: uint }
)

;; Read-only functions

;; Get pool information by ID
(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id)
)

;; Get pool ID by token pair
(define-read-only (get-pool-id (token-a principal) (token-b principal))
  (match (map-get? pool-lookup { token-a: token-a, token-b: token-b })
    pool-id (some pool-id)
    (map-get? pool-lookup { token-a: token-b, token-b: token-a })
  )
)

;; Get liquidity provider shares
(define-read-only (get-liquidity-shares (pool-id uint) (provider principal))
  (default-to u0 (map-get? liquidity-shares { pool-id: pool-id, provider: provider }))
)

;; Calculate swap output amount with fees
(define-read-only (calculate-swap-output (pool-id uint) (token-in principal) (amount-in uint))
  (match (map-get? pools pool-id)
    pool
    (let
      (
        (reserve-in (if (is-eq token-in (get token-a pool))
                       (get reserve-a pool)
                       (get reserve-b pool)))
        (reserve-out (if (is-eq token-in (get token-a pool))
                        (get reserve-b pool)
                        (get reserve-a pool)))
        (fee-rate (get fee-rate pool))
        (amount-in-with-fee (- (* amount-in (- u10000 fee-rate)) (/ (* amount-in fee-rate) u10000)))
        (numerator (* amount-in-with-fee reserve-out))
        (denominator (+ reserve-in amount-in-with-fee))
      )
      (if (> denominator u0)
        (ok (/ numerator denominator))
        ERR_INSUFFICIENT_LIQUIDITY
      )
    )
    ERR_POOL_NOT_FOUND
  )
)

;; Get protocol configuration
(define-read-only (get-protocol-info)
  {
    protocol-fee: (var-get protocol-fee),
    fee-recipient: (var-get fee-recipient),
    paused: (var-get paused),
    next-pool-id: (var-get next-pool-id),
    next-swap-id: (var-get next-swap-id)
  }
)

;; Get detailed pool statistics
(define-read-only (get-pool-stats (pool-id uint))
  (match (map-get? pools pool-id)
    pool
    (let
      (
        (reserve-a (get reserve-a pool))
        (reserve-b (get reserve-b pool))
        (total-supply (get total-supply pool))
        (k-value (* reserve-a reserve-b))
        (price-a-in-b (if (> reserve-a u0) (/ (* reserve-b PRECISION) reserve-a) u0))
        (price-b-in-a (if (> reserve-b u0) (/ (* reserve-a PRECISION) reserve-b) u0))
      )
      (ok {
        pool-id: pool-id,
        reserve-a: reserve-a,
        reserve-b: reserve-b,
        total-supply: total-supply,
        k-value: k-value,
        price-a-in-b: price-a-in-b,
        price-b-in-a: price-b-in-a,
        utilization-rate: (if (> total-supply u0)
                            (/ (* (+ reserve-a reserve-b) u100) total-supply)
                            u0),
        active: (get active pool),
        fee-rate: (get fee-rate pool),
        created-at: (get created-at pool)
      })
    )
    (err ERR_POOL_NOT_FOUND)
  )
)

;; Calculate price impact for a potential swap
(define-read-only (calculate-price-impact (pool-id uint) (token-in principal) (amount-in uint))
  (match (map-get? pools pool-id)
    pool
    (let
      (
        (reserve-in (if (is-eq token-in (get token-a pool))
                       (get reserve-a pool)
                       (get reserve-b pool)))
        (reserve-out (if (is-eq token-in (get token-a pool))
                        (get reserve-b pool)
                        (get reserve-a pool)))
        (current-price (if (> reserve-in u0) (/ (* reserve-out PRECISION) reserve-in) u0))
        (amount-out-result (calculate-swap-output pool-id token-in amount-in))
      )
      (match amount-out-result
        amount-out
        (let
          (
            (new-reserve-in (+ reserve-in amount-in))
            (new-reserve-out (- reserve-out amount-out))
            (new-price (if (> new-reserve-in u0) (/ (* new-reserve-out PRECISION) new-reserve-in) u0))
            (price-change (if (> current-price u0)
                            (if (> new-price current-price)
                              (/ (* (- new-price current-price) u10000) current-price)
                              (/ (* (- current-price new-price) u10000) current-price))
                            u0))
          )
          (ok {
            current-price: current-price,
            new-price: new-price,
            price-impact: price-change,
            amount-out: amount-out
          })
        )
        error-code (err error-code)
      )
    )
    (err ERR_POOL_NOT_FOUND)
  )
)

;; Get pool health metrics
(define-read-only (get-pool-health (pool-id uint))
  (match (map-get? pools pool-id)
    pool
    (let
      (
        (reserve-a (get reserve-a pool))
        (reserve-b (get reserve-b pool))
        (total-supply (get total-supply pool))
        (min-reserve (min reserve-a reserve-b))
        (max-reserve (max reserve-a reserve-b))
        (balance-ratio (if (> min-reserve u0) (/ (* max-reserve u100) min-reserve) u0))
        (liquidity-depth (+ reserve-a reserve-b))
      )
      (ok {
        pool-id: pool-id,
        balance-ratio: balance-ratio,
        liquidity-depth: liquidity-depth,
        is-balanced: (< balance-ratio u200), ;; Less than 2:1 ratio
        min-liquidity-met: (>= total-supply MIN_LIQUIDITY),
        health-score: (if (and (< balance-ratio u200) (>= total-supply MIN_LIQUIDITY))
                        u100 ;; Healthy
                        (if (< balance-ratio u500) u50 u10)) ;; Moderate or Poor
      })
    )
    (err ERR_POOL_NOT_FOUND)
  )
)

;; Get cross-chain swap information
(define-read-only (get-cross-chain-swap (swap-id uint))
  (map-get? cross-chain-swaps swap-id)
)

;; Get fee statistics for a pool
(define-read-only (get-pool-fees (pool-id uint))
  (match (map-get? pool-fees-collected pool-id)
    fees (ok fees)
    (ok { total-fees-a: u0, total-fees-b: u0, last-updated: u0 })
  )
)

;; Get protocol fees collected for a token
(define-read-only (get-protocol-fees (token principal))
  (match (map-get? protocol-fees-collected token)
    fees (ok fees)
    (ok { total-collected: u0, last-updated: u0 })
  )
)

;; Get comprehensive pool analytics
(define-read-only (get-pool-analytics (pool-id uint))
  (match (get-pool-stats pool-id)
    stats
    (match (get-pool-health pool-id)
      health
      (match (get-pool-fees pool-id)
        fees
        (ok {
          basic-stats: stats,
          health-metrics: health,
          fee-stats: fees
        })
        error (err error)
      )
      error (err error)
    )
    error (err error)
  )
)

;; Get multiple pools with basic info (for pagination)
(define-read-only (get-pools-range (start-id uint) (end-id uint))
  (let
    (
      (max-id (- (var-get next-pool-id) u1))
      (actual-end (min end-id max-id))
    )
    (if (and (<= start-id actual-end) (> actual-end u0))
      (ok (map get-pool-basic (list start-id (+ start-id u1) (+ start-id u2) (+ start-id u3) (+ start-id u4))))
      (ok (list))
    )
  )
)

;; Helper function to get basic pool info
(define-private (get-pool-basic (pool-id uint))
  (match (map-get? pools pool-id)
    pool
    (some {
      pool-id: pool-id,
      token-a: (get token-a pool),
      token-b: (get token-b pool),
      reserve-a: (get reserve-a pool),
      reserve-b: (get reserve-b pool),
      active: (get active pool),
      fee-rate: (get fee-rate pool)
    })
    none
  )
)

;; Private functions

;; Check if caller is contract owner
(define-private (is-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

;; Check if protocol is not paused
(define-private (not-paused)
  (not (var-get paused))
)

;; Sort token addresses for consistent pool lookup
(define-private (sort-tokens (token-a principal) (token-b principal))
  (if (< (principal-to-uint token-a) (principal-to-uint token-b))
    { token-a: token-a, token-b: token-b }
    { token-a: token-b, token-b: token-a }
  )
)

;; Convert principal to uint for comparison (simplified)
(define-private (principal-to-uint (p principal))
  ;; This is a simplified conversion - in production, use a more robust method
  (len (unwrap-panic (to-consensus-buff? p)))
)

;; Public functions

;; Create a new liquidity pool
(define-public (create-pool 
  (token-a <sip-010-trait>) 
  (token-b <sip-010-trait>) 
  (initial-a uint) 
  (initial-b uint)
  (fee-rate uint))
  (let
    (
      (pool-id (var-get next-pool-id))
      (token-a-principal (contract-of token-a))
      (token-b-principal (contract-of token-b))
      (sorted-tokens (sort-tokens token-a-principal token-b-principal))
    )
    (asserts! (not-paused) ERR_PAUSED)
    (asserts! (> initial-a u0) ERR_INVALID_AMOUNT)
    (asserts! (> initial-b u0) ERR_INVALID_AMOUNT)
    (asserts! (<= fee-rate MAX_FEE) ERR_INVALID_FEE)
    (asserts! (is-none (get-pool-id token-a-principal token-b-principal)) ERR_ALREADY_EXISTS)
    
    ;; Transfer initial liquidity from sender
    (try! (contract-call? token-a transfer initial-a tx-sender (as-contract tx-sender) none))
    (try! (contract-call? token-b transfer initial-b tx-sender (as-contract tx-sender) none))
    
    ;; Calculate initial LP tokens (geometric mean)
    (let ((initial-liquidity (sqrti (* initial-a initial-b))))
      ;; Create pool
      (map-set pools pool-id
        {
          token-a: (get token-a sorted-tokens),
          token-b: (get token-b sorted-tokens),
          reserve-a: (if (is-eq (get token-a sorted-tokens) token-a-principal) initial-a initial-b),
          reserve-b: (if (is-eq (get token-a sorted-tokens) token-a-principal) initial-b initial-a),
          total-supply: initial-liquidity,
          fee-rate: fee-rate,
          created-at: block-height,
          active: true
        }
      )
      
      ;; Set pool lookup
      (map-set pool-lookup sorted-tokens pool-id)
      
      ;; Mint LP tokens to creator
      (map-set liquidity-shares { pool-id: pool-id, provider: tx-sender } initial-liquidity)
      
      ;; Increment pool counter
      (var-set next-pool-id (+ pool-id u1))
      
      (ok pool-id)
    )
  )
)

;; Add liquidity to an existing pool
(define-public (add-liquidity
  (pool-id uint)
  (token-a <sip-010-trait>)
  (token-b <sip-010-trait>)
  (amount-a uint)
  (amount-b uint)
  (min-liquidity uint))
  (let
    (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
      (reserve-a (get reserve-a pool))
      (reserve-b (get reserve-b pool))
      (total-supply (get total-supply pool))
    )
    (asserts! (not-paused) ERR_PAUSED)
    (asserts! (get active pool) ERR_POOL_NOT_FOUND)
    (asserts! (> amount-a u0) ERR_INVALID_AMOUNT)
    (asserts! (> amount-b u0) ERR_INVALID_AMOUNT)

    ;; Calculate optimal amounts based on current ratio
    (let
      (
        (optimal-b (/ (* amount-a reserve-b) reserve-a))
        (optimal-a (/ (* amount-b reserve-a) reserve-b))
        (final-a (if (<= optimal-b amount-b) amount-a optimal-a))
        (final-b (if (<= optimal-b amount-b) optimal-b amount-b))
        (liquidity-minted (min (/ (* final-a total-supply) reserve-a)
                              (/ (* final-b total-supply) reserve-b)))
      )
      (asserts! (>= liquidity-minted min-liquidity) ERR_SLIPPAGE_TOO_HIGH)

      ;; Transfer tokens from user
      (try! (contract-call? token-a transfer final-a tx-sender (as-contract tx-sender) none))
      (try! (contract-call? token-b transfer final-b tx-sender (as-contract tx-sender) none))

      ;; Update pool reserves
      (map-set pools pool-id
        (merge pool {
          reserve-a: (+ reserve-a final-a),
          reserve-b: (+ reserve-b final-b),
          total-supply: (+ total-supply liquidity-minted)
        })
      )

      ;; Update user's liquidity shares
      (let ((current-shares (get-liquidity-shares pool-id tx-sender)))
        (map-set liquidity-shares
          { pool-id: pool-id, provider: tx-sender }
          (+ current-shares liquidity-minted)
        )
      )

      (ok { liquidity-minted: liquidity-minted, amount-a: final-a, amount-b: final-b })
    )
  )
)

;; Remove liquidity from a pool
(define-public (remove-liquidity
  (pool-id uint)
  (token-a <sip-010-trait>)
  (token-b <sip-010-trait>)
  (liquidity-amount uint)
  (min-amount-a uint)
  (min-amount-b uint))
  (let
    (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
      (user-shares (get-liquidity-shares pool-id tx-sender))
      (reserve-a (get reserve-a pool))
      (reserve-b (get reserve-b pool))
      (total-supply (get total-supply pool))
    )
    (asserts! (not-paused) ERR_PAUSED)
    (asserts! (>= user-shares liquidity-amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> liquidity-amount u0) ERR_INVALID_AMOUNT)

    ;; Calculate amounts to return
    (let
      (
        (amount-a (/ (* liquidity-amount reserve-a) total-supply))
        (amount-b (/ (* liquidity-amount reserve-b) total-supply))
      )
      (asserts! (>= amount-a min-amount-a) ERR_SLIPPAGE_TOO_HIGH)
      (asserts! (>= amount-b min-amount-b) ERR_SLIPPAGE_TOO_HIGH)

      ;; Update user's liquidity shares
      (map-set liquidity-shares
        { pool-id: pool-id, provider: tx-sender }
        (- user-shares liquidity-amount)
      )

      ;; Update pool reserves
      (map-set pools pool-id
        (merge pool {
          reserve-a: (- reserve-a amount-a),
          reserve-b: (- reserve-b amount-b),
          total-supply: (- total-supply liquidity-amount)
        })
      )

      ;; Transfer tokens back to user
      (try! (as-contract (contract-call? token-a transfer amount-a tx-sender tx-sender none)))
      (try! (as-contract (contract-call? token-b transfer amount-b tx-sender tx-sender none)))

      (ok { amount-a: amount-a, amount-b: amount-b })
    )
  )
)

;; Perform a token swap within a pool
(define-public (swap-tokens
  (pool-id uint)
  (token-in <sip-010-trait>)
  (token-out <sip-010-trait>)
  (amount-in uint)
  (min-amount-out uint))
  (let
    (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
      (token-in-principal (contract-of token-in))
      (token-out-principal (contract-of token-out))
    )
    (asserts! (not-paused) ERR_PAUSED)
    (asserts! (get active pool) ERR_POOL_NOT_FOUND)
    (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
    (asserts! (or (and (is-eq token-in-principal (get token-a pool))
                       (is-eq token-out-principal (get token-b pool)))
                  (and (is-eq token-in-principal (get token-b pool))
                       (is-eq token-out-principal (get token-a pool))))
              ERR_INVALID_TOKEN)

    ;; Calculate swap output
    (let
      (
        (amount-out (unwrap! (calculate-swap-output pool-id token-in-principal amount-in) ERR_INSUFFICIENT_LIQUIDITY))
        (is-a-to-b (is-eq token-in-principal (get token-a pool)))
        (reserve-in (if is-a-to-b (get reserve-a pool) (get reserve-b pool)))
        (reserve-out (if is-a-to-b (get reserve-b pool) (get reserve-a pool)))
        (protocol-fee-amount (/ (* amount-in (var-get protocol-fee)) u10000))
      )
      (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)
      (asserts! (< amount-out reserve-out) ERR_INSUFFICIENT_LIQUIDITY)

      ;; Transfer input tokens from user
      (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))

      ;; Transfer protocol fee to fee recipient
      (if (> protocol-fee-amount u0)
        (try! (as-contract (contract-call? token-in transfer protocol-fee-amount tx-sender (var-get fee-recipient) none)))
        true
      )

      ;; Update pool reserves
      (map-set pools pool-id
        (merge pool {
          reserve-a: (if is-a-to-b (+ (get reserve-a pool) (- amount-in protocol-fee-amount)) (- (get reserve-a pool) amount-out)),
          reserve-b: (if is-a-to-b (- (get reserve-b pool) amount-out) (+ (get reserve-b pool) (- amount-in protocol-fee-amount)))
        })
      )

      ;; Transfer output tokens to user
      (try! (as-contract (contract-call? token-out transfer amount-out tx-sender tx-sender none)))

      ;; Update fee tracking
      (let
        (
          (current-pool-fees (default-to { total-fees-a: u0, total-fees-b: u0, last-updated: u0 }
                                         (map-get? pool-fees-collected pool-id)))
          (pool-fee-amount (/ (* amount-in (get fee-rate pool)) u10000))
        )
        (map-set pool-fees-collected pool-id
          {
            total-fees-a: (if is-a-to-b
                            (+ (get total-fees-a current-pool-fees) pool-fee-amount)
                            (get total-fees-a current-pool-fees)),
            total-fees-b: (if is-a-to-b
                            (get total-fees-b current-pool-fees)
                            (+ (get total-fees-b current-pool-fees) pool-fee-amount)),
            last-updated: block-height
          }
        )

        ;; Update protocol fee tracking
        (let
          (
            (current-protocol-fees (default-to { total-collected: u0, last-updated: u0 }
                                              (map-get? protocol-fees-collected token-in-principal)))
          )
          (map-set protocol-fees-collected token-in-principal
            {
              total-collected: (+ (get total-collected current-protocol-fees) protocol-fee-amount),
              last-updated: block-height
            }
          )
        )
      )

      (ok {
        amount-in: amount-in,
        amount-out: amount-out,
        protocol-fee: protocol-fee-amount,
        pool-fee: (/ (* amount-in (get fee-rate pool)) u10000),
        price-impact: (unwrap-panic (get price-impact (unwrap-panic (calculate-price-impact pool-id token-in-principal amount-in))))
      })
    )
  )
)

;; Initiate a cross-chain swap
(define-public (initiate-cross-chain-swap
  (source-token <sip-010-trait>)
  (target-token-address (string-ascii 64))
  (target-chain (string-ascii 32))
  (amount uint)
  (target-address (string-ascii 64))
  (expires-in-blocks uint))
  (let
    (
      (swap-id (var-get next-swap-id))
      (expires-at (+ block-height expires-in-blocks))
    )
    (asserts! (not-paused) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> expires-in-blocks u0) ERR_INVALID_AMOUNT)

    ;; Transfer source tokens to contract
    (try! (contract-call? source-token transfer amount tx-sender (as-contract tx-sender) none))

    ;; Record cross-chain swap
    (map-set cross-chain-swaps swap-id
      {
        initiator: tx-sender,
        source-token: (contract-of source-token),
        target-token: target-token-address,
        source-amount: amount,
        target-amount: u0, ;; To be set when completed
        target-chain: target-chain,
        target-address: target-address,
        status: "pending",
        created-at: block-height,
        expires-at: expires-at
      }
    )

    ;; Increment swap counter
    (var-set next-swap-id (+ swap-id u1))

    (ok swap-id)
  )
)

;; Complete a cross-chain swap (called by authorized relayer)
(define-public (complete-cross-chain-swap
  (swap-id uint)
  (target-amount uint)
  (proof (buff 256))) ;; Simplified proof - in production use proper cryptographic proof
  (let
    (
      (swap (unwrap! (map-get? cross-chain-swaps swap-id) ERR_POOL_NOT_FOUND))
    )
    (asserts! (is-owner) ERR_UNAUTHORIZED) ;; In production, use proper relayer authorization
    (asserts! (is-eq (get status swap) "pending") ERR_INVALID_AMOUNT)
    (asserts! (< block-height (get expires-at swap)) ERR_SWAP_EXPIRED)

    ;; Update swap status
    (map-set cross-chain-swaps swap-id
      (merge swap {
        target-amount: target-amount,
        status: "completed"
      })
    )

    (ok true)
  )
)

;; Cancel an expired cross-chain swap
(define-public (cancel-cross-chain-swap (swap-id uint))
  (let
    (
      (swap (unwrap! (map-get? cross-chain-swaps swap-id) ERR_POOL_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get initiator swap)) (is-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status swap) "pending") ERR_INVALID_AMOUNT)
    (asserts! (>= block-height (get expires-at swap)) ERR_SWAP_EXPIRED)

    ;; Update swap status
    (map-set cross-chain-swaps swap-id
      (merge swap { status: "failed" })
    )

    ;; Return tokens to initiator (simplified - in production, handle different token types)
    ;; This would need proper token contract handling

    (ok true)
  )
)

;; Admin Functions

;; Set protocol fee (only owner)
(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee MAX_FEE) ERR_INVALID_FEE)
    (var-set protocol-fee new-fee)
    (ok true)
  )
)

;; Set fee recipient (only owner)
(define-public (set-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set fee-recipient new-recipient)
    (ok true)
  )
)

;; Pause/unpause protocol (only owner)
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set paused pause)
    (ok true)
  )
)

;; Deactivate a pool (only owner)
(define-public (deactivate-pool (pool-id uint))
  (let
    (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
    )
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set pools pool-id (merge pool { active: false }))
    (ok true)
  )
)

;; Emergency withdraw function (only owner, when paused)
(define-public (emergency-withdraw
  (token <sip-010-trait>)
  (amount uint)
  (recipient principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (var-get paused) ERR_UNAUTHORIZED)
    (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
    (ok true)
  )
)
