;; Carbon Credit Token (CCT) Smart Contract
;; A comprehensive contract for managing carbon credits on Stacks blockchain

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_TOKEN_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_RETIRED (err u104))
(define-constant ERR_INVALID_RECIPIENT (err u105))
(define-constant ERR_TRANSFER_FAILED (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_STRING (err u108))

;; Data Variables
(define-data-var token-name (string-ascii 32) "Carbon Credit Token")
(define-data-var token-symbol (string-ascii 10) "CCT")
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)
(define-data-var next-token-id uint u1)
(define-data-var contract-paused bool false)

;; Data Maps
(define-map token-balances principal uint)
(define-map token-allowances {owner: principal, spender: principal} uint)
(define-map token-metadata 
  uint 
  {
    project-id: (string-ascii 64),
    vintage: uint,
    methodology: (string-ascii 32),
    verification-body: (string-ascii 32),
    co2-amount: uint,
    retired: bool,
    retirement-date: (optional uint)
  }
)
(define-map project-totals (string-ascii 64) uint)
(define-map authorized-verifiers principal bool)
(define-map retired-credits principal uint)

;; Input Validation Functions
(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

(define-private (is-valid-principal (address principal))
  (not (is-eq address 'SP000000000000000000002Q6VF78))
)

(define-private (is-valid-string (str (string-ascii 64)))
  (> (len str) u0)
)

(define-private (is-valid-string-32 (str (string-ascii 32)))
  (> (len str) u0)
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-verifier)
  (default-to false (map-get? authorized-verifiers tx-sender))
)

;; Read-only Functions
(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? token-balances who)))
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (map-get? token-allowances {owner: owner, spender: spender})))
)

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id)
)

(define-read-only (get-project-total (project-id (string-ascii 64)))
  (ok (default-to u0 (map-get? project-totals project-id)))
)

(define-read-only (get-retired-credits (user principal))
  (ok (default-to u0 (map-get? retired-credits user)))
)

(define-read-only (is-contract-paused)
  (ok (var-get contract-paused))
)

;; Private Helper Functions
(define-private (transfer-helper (sender principal) (recipient principal) (amount uint))
  (let (
    (sender-balance (default-to u0 (map-get? token-balances sender)))
    (recipient-balance (default-to u0 (map-get? token-balances recipient)))
  )
    (asserts! (is-valid-principal sender) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (is-eq sender recipient)) ERR_INVALID_RECIPIENT)
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    
    (map-set token-balances sender (- sender-balance amount))
    (map-set token-balances recipient (+ recipient-balance amount))
    
    (print {
      type: "transfer",
      sender: sender,
      recipient: recipient,
      amount: amount
    })
    (ok true)
  )
)

;; Public Functions

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal sender) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (try! (transfer-helper sender recipient amount))
    (ok true)
  )
)

;; Transfer from (for allowances)
(define-public (transfer-from (amount uint) (sender principal) (recipient principal))
  (let (
    (allowance (default-to u0 (map-get? token-allowances {owner: sender, spender: tx-sender})))
  )
    (asserts! (is-valid-principal sender) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (>= allowance amount) ERR_UNAUTHORIZED)
    (try! (transfer-helper sender recipient amount))
    (map-set token-allowances {owner: sender, spender: tx-sender} (- allowance amount))
    (ok true)
  )
)

;; Approve allowance
(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (is-valid-principal spender) ERR_INVALID_PRINCIPAL)
    (asserts! (>= amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (map-set token-allowances {owner: tx-sender, spender: spender} amount)
    (print {
      type: "approval",
      owner: tx-sender,
      spender: spender,
      amount: amount
    })
    (ok true)
  )
)

;; Mint new carbon credits (only authorized verifiers)
(define-public (mint-carbon-credits 
  (recipient principal) 
  (amount uint) 
  (project-id (string-ascii 64)) 
  (vintage uint) 
  (methodology (string-ascii 32)) 
  (verification-body (string-ascii 32))
)
  (let (
    (token-id (var-get next-token-id))
    (current-balance (default-to u0 (map-get? token-balances recipient)))
    (current-project-total (default-to u0 (map-get? project-totals project-id)))
  )
    (asserts! (or (is-contract-owner) (is-authorized-verifier)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-string project-id) ERR_INVALID_STRING)
    (asserts! (> vintage u1900) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-string-32 methodology) ERR_INVALID_STRING)
    (asserts! (is-valid-string-32 verification-body) ERR_INVALID_STRING)
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    
    ;; Update balances and supply
    (map-set token-balances recipient (+ current-balance amount))
    (var-set total-supply (+ (var-get total-supply) amount))
    (var-set next-token-id (+ token-id u1))
    
    ;; Store token metadata
    (map-set token-metadata token-id {
      project-id: project-id,
      vintage: vintage,
      methodology: methodology,
      verification-body: verification-body,
      co2-amount: amount,
      retired: false,
      retirement-date: none
    })
    
    ;; Update project totals
    (map-set project-totals project-id (+ current-project-total amount))
    
    (print {
      type: "mint",
      recipient: recipient,
      amount: amount,
      token-id: token-id,
      project-id: project-id
    })
    (ok token-id)
  )
)

;; Retire carbon credits (burn)
(define-public (retire-credits (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances tx-sender)))
    (current-retired (default-to u0 (map-get? retired-credits tx-sender)))
  )
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    
    ;; Burn tokens
    (map-set token-balances tx-sender (- current-balance amount))
    (var-set total-supply (- (var-get total-supply) amount))
    
    ;; Track retired credits
    (map-set retired-credits tx-sender (+ current-retired amount))
    
    (print {
      type: "retirement",
      retiree: tx-sender,
      amount: amount,
      block-height: stacks-block-height
    })
    (ok true)
  )
)

;; Admin Functions

;; Add authorized verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal verifier) ERR_INVALID_PRINCIPAL)
    (map-set authorized-verifiers verifier true)
    (print {type: "verifier-added", verifier: verifier})
    (ok true)
  )
)

;; Remove authorized verifier (only contract owner)
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal verifier) ERR_INVALID_PRINCIPAL)
    (map-delete authorized-verifiers verifier)
    (print {type: "verifier-removed", verifier: verifier})
    (ok true)
  )
)

;; Pause/unpause contract (only contract owner)
(define-public (set-contract-paused (paused bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-paused paused)
    (print {type: "contract-paused", paused: paused})
    (ok true)
  )
)

;; Batch transfer for efficiency
(define-public (batch-transfer (transfers (list 10 {recipient: principal, amount: uint})))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (fold batch-transfer-helper transfers (ok true))
  )
)

(define-private (batch-transfer-helper 
  (transfer-data {recipient: principal, amount: uint}) 
  (previous-result (response bool uint))
)
  (match previous-result
    success (begin
      (asserts! (is-valid-principal (get recipient transfer-data)) ERR_INVALID_PRINCIPAL)
      (asserts! (is-valid-amount (get amount transfer-data)) ERR_INVALID_AMOUNT)
      (transfer-helper tx-sender (get recipient transfer-data) (get amount transfer-data))
    )
    error (err error)
  )
)