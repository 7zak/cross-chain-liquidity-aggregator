;; Mock Token B for Testing
;; Implements SIP-010 Fungible Token Standard

(impl-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant TOKEN_NAME "Mock Token B")
(define-constant TOKEN_SYMBOL "MOCKB")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOKEN_URI u"https://example.com/mock-token-b")

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_INVALID_AMOUNT (err u403))

;; Data variables
(define-data-var total-supply uint u2000000000000) ;; 2M tokens with 6 decimals
(define-data-var token-uri (string-utf8 256) u"https://example.com/mock-token-b")

;; Data maps
(define-map balances principal uint)
(define-map allowances { owner: principal, spender: principal } uint)

;; Initialize contract owner balance
(map-set balances CONTRACT_OWNER (var-get total-supply))

;; SIP-010 Implementation

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (get-balance-of sender)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update balances
    (map-set balances sender (- (get-balance-of sender) amount))
    (map-set balances recipient (+ (get-balance-of recipient) amount))
    
    ;; Print transfer event
    (print {
      type: "transfer",
      token: "MOCKB",
      amount: amount,
      sender: sender,
      recipient: recipient,
      memo: memo
    })
    
    (ok true)
  )
)

(define-read-only (get-name)
  (ok TOKEN_NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

(define-read-only (get-balance (account principal))
  (ok (get-balance-of account))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (some (var-get token-uri)))
)

;; Helper functions
(define-private (get-balance-of (account principal))
  (default-to u0 (map-get? balances account))
)

;; Mint function for testing (only owner)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update total supply and recipient balance
    (var-set total-supply (+ (var-get total-supply) amount))
    (map-set balances recipient (+ (get-balance-of recipient) amount))
    
    (print {
      type: "mint",
      token: "MOCKB",
      amount: amount,
      recipient: recipient
    })
    
    (ok true)
  )
)

;; Burn function for testing (only owner)
(define-public (burn (amount uint) (account principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (get-balance-of account)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update total supply and account balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances account (- (get-balance-of account) amount))
    
    (print {
      type: "burn",
      token: "MOCKB",
      amount: amount,
      account: account
    })
    
    (ok true)
  )
)
