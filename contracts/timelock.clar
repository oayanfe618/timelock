;; ============================================================
;; Contract Name: time-lock-savings-dao
;; Description:
;; A full Clarity smart contract implementing:
;; - Time-locked savings vault
;; - Interest-style reward distribution
;; - Emergency withdrawal with penalty
;; - DAO governance for parameters
;; - User reputation for long-term saving
;; ============================================================

;; -------------------------
;; Errors
;; -------------------------
(define-constant ERR-AUTH (err u100))
(define-constant ERR-STATE (err u101))
(define-constant ERR-BALANCE (err u102))
(define-constant ERR-NOT-FOUND (err u103))

;; -------------------------
;; Data Variables
;; -------------------------
(define-data-var pool-balance uint u0)
(define-data-var reward-rate uint u5) ;; 5% reward
(define-data-var penalty-rate uint u10) ;; 10% early withdrawal penalty
(define-data-var proposal-count uint u0)

;; -------------------------
;; Maps
;; -------------------------

;; User savings vault
(define-map savings
  principal
  {
    amount: uint,
    unlock-block: uint
  }
)

;; User reputation
(define-map reputation principal uint)

;; DAO proposals (parameter changes)
(define-map proposals
  uint
  {
    proposer: principal,
    new-reward: uint,
    new-penalty: uint,
    end-block: uint,
    yes: uint,
    no: uint,
    executed: bool
  }
)

;; Voting record
(define-map votes {proposal: uint, voter: principal} bool)

;; -------------------------
;; Private Helpers
;; -------------------------

(define-private (add-reputation (user principal))
  (let ((current (default-to u0 (map-get? reputation user))))
    (map-set reputation user (+ current u1))))

;; -------------------------
;; Savings Functions
;; -------------------------

(define-public (lock-savings (amount uint) (duration uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set savings tx-sender {
      amount: amount,
      unlock-block: (+ burn-block-height duration)
    })
    (var-set pool-balance (+ (var-get pool-balance) amount))
    (ok true)))

(define-public (withdraw)
  (let ((record (unwrap! (map-get? savings tx-sender) ERR-NOT-FOUND)))
    (let ((amount (get amount record))
          (unlock (get unlock-block record)))
      (begin
        (map-delete savings tx-sender)
        (if (>= burn-block-height unlock)
            ;; normal withdrawal + reward
            (let ((reward (/ (* amount (var-get reward-rate)) u100)))
              (try! (stx-transfer? (+ amount reward) (as-contract tx-sender) tx-sender))
              (add-reputation tx-sender)
              (ok true))
            ;; early withdrawal with penalty
            (let ((penalty (/ (* amount (var-get penalty-rate)) u100)))
              (try! (stx-transfer? (- amount penalty) (as-contract tx-sender) tx-sender))
              (var-set pool-balance (+ (var-get pool-balance) penalty))
              (ok true)))))))

;; -------------------------
;; DAO Governance
;; -------------------------

(define-public (create-proposal (new-reward uint) (new-penalty uint) (duration uint))
  (let ((id (+ (var-get proposal-count) u1)))
    (map-set proposals id {
      proposer: tx-sender,
      new-reward: new-reward,
      new-penalty: new-penalty,
      end-block: (+ burn-block-height duration),
      yes: u0,
      no: u0,
      executed: false
    })
    (var-set proposal-count id)
    (ok id)))

(define-public (vote (proposal-id uint) (support bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND)))
    (if (or (>= burn-block-height (get end-block proposal))
            (is-some (map-get? votes {proposal: proposal-id, voter: tx-sender})))
        ERR-STATE
        (begin
          (map-set votes {proposal: proposal-id, voter: tx-sender} true)
          (if support
              (map-set proposals proposal-id (merge proposal {yes: (+ (get yes proposal) u1)}))
              (map-set proposals proposal-id (merge proposal {no: (+ (get no proposal) u1)})))
          (ok true)))))

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND)))
    (if (or (get executed proposal)
            (< burn-block-height (get end-block proposal))
            (<= (get yes proposal) (get no proposal)))
        ERR-STATE
        (begin
          (var-set reward-rate (get new-reward proposal))
          (var-set penalty-rate (get new-penalty proposal))
          (map-set proposals proposal-id (merge proposal {executed: true}))
          (ok true)))))

;; -------------------------
;; Admin & Pool Management
;; -------------------------

;; Add external rewards to pool (grants, donations)
(define-public (donate-to-pool (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set pool-balance (+ (var-get pool-balance) amount))
    (ok true)))

;; Extend lock duration (cannot shorten)
(define-public (extend-lock (extra-blocks uint))
  (let ((record (unwrap! (map-get? savings tx-sender) ERR-NOT-FOUND)))
    (map-set savings tx-sender {
      amount: (get amount record),
      unlock-block: (+ (get unlock-block record) extra-blocks)
    })
    (ok true)))

;; Compound rewards by re-locking after maturity
(define-public (compound)
  (let ((record (unwrap! (map-get? savings tx-sender) ERR-NOT-FOUND)))
    (if (< burn-block-height (get unlock-block record))
        ERR-STATE
        (let ((reward (/ (* (get amount record) (var-get reward-rate)) u100)))
          (begin
            (map-set savings tx-sender {
              amount: (+ (get amount record) reward),
              unlock-block: (+ burn-block-height u144)
            })
            (add-reputation tx-sender)
            (ok true))))))

;; -------------------------
;; Read-only Functions
;; -------------------------

(define-read-only (get-savings (user principal))
  (map-get? savings user))

(define-read-only (get-reputation (user principal))
  (default-to u0 (map-get? reputation user)))

(define-read-only (get-parameters)
  {
    reward-rate: (var-get reward-rate),
    penalty-rate: (var-get penalty-rate),
    pool-balance: (var-get pool-balance)
  })

;; ============================================================
;; End of time-lock-savings-dao
;; ============================================================

