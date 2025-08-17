;; Gaming Currency Token Contract
;; Design tokens to serve as in-game currency for purchases and rewards

;; Define the gaming token
(define-fungible-token game-coin)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-unauthorized (err u104))

;; Token metadata
(define-data-var token-name (string-ascii 32) "GameCoin")
(define-data-var token-symbol (string-ascii 10) "GCOIN")
(define-data-var token-decimals uint u6)

;; Supply tracking
(define-data-var total-supply uint u0)

;; Game mechanics tracking
(define-map player-rewards principal uint)
(define-map authorized-games principal bool)
(define-data-var total-rewards-distributed uint u0)

;; Function 1: Reward players with gaming tokens
(define-public (reward-player (player principal) (amount uint) (reward-type (string-ascii 64)))
  (begin
    ;; Only authorized games or contract owner can reward players
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (default-to false (map-get? authorized-games tx-sender))) 
              err-unauthorized)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Mint tokens to player
    (try! (ft-mint? game-coin amount player))
    
    ;; Update total supply
    (var-set total-supply (+ (var-get total-supply) amount))
    
    ;; Track player rewards
    (map-set player-rewards player 
             (+ (default-to u0 (map-get? player-rewards player)) amount))
    
    ;; Update total rewards distributed
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) amount))
    
    ;; Print event for logging
    (print {
      action: "reward-player",
      player: player,
      amount: amount,
      reward-type: reward-type,
      timestamp: stacks-block-height
    })
    
    (ok amount)
  )
)

;; Function 2: Spend gaming tokens for in-game purchases
(define-public (spend-tokens (amount uint) (item-id (string-ascii 64)) (game-contract principal))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (ft-get-balance game-coin tx-sender) amount) err-insufficient-balance)
    
    ;; Verify the game contract is authorized
    (asserts! (default-to false (map-get? authorized-games game-contract)) err-unauthorized)
    
    ;; Burn tokens from player (spending them)
    (try! (ft-burn? game-coin amount tx-sender))
    
    ;; Update total supply
    (var-set total-supply (- (var-get total-supply) amount))
    
    ;; Print event for logging the purchase
    (print {
      action: "spend-tokens",
      player: tx-sender,
      amount: amount,
      item-id: item-id,
      game-contract: game-contract,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Owner function: Authorize game contracts
(define-public (authorize-game (game-contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-games game-contract true)
    (ok true)
  )
)

;; Owner function: Revoke game authorization
(define-public (revoke-game (game-contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-games game-contract false)
    (ok true)
  )
)

;; Read-only functions

;; Get token balance
(define-read-only (get-balance (account principal))
  (ok (ft-get-balance game-coin account)))

;; Get token metadata
(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (get-decimals)
  (ok (var-get token-decimals)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

;; Get player's total rewards received
(define-read-only (get-player-rewards (player principal))
  (ok (default-to u0 (map-get? player-rewards player))))

;; Check if game is authorized
(define-read-only (is-game-authorized (game-contract principal))
  (ok (default-to false (map-get? authorized-games game-contract))))

;; Get total rewards distributed
(define-read-only (get-total-rewards-distributed)
  (ok (var-get total-rewards-distributed)))

;; Get token URI (for NFT marketplaces compatibility)
(define-read-only (get-token-uri)
  (ok (some u"https://gametoken.example.com/metadata.json")))