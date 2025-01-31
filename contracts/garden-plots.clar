;; Garden Plot Rental Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-plot-taken (err u101))
(define-constant err-not-plot-owner (err u102))
(define-constant err-invalid-plot (err u103))
(define-constant err-expired (err u104))
(define-constant err-insufficient-funds (err u105))

;; Data variables  
(define-data-var total-plots uint u100)
(define-data-var rental-price uint u100)
(define-data-var loyalty-discount uint u10) ;; Percentage discount for extensions
(define-data-var total-rewards uint u0)

;; Data maps
(define-map plots uint {owner: (optional principal), expiry: uint})
(define-map plot-details uint {size: uint, location: (string-ascii 50)})
(define-map user-stats principal {total-rentals: uint, rewards: uint})

;; Public functions
(define-public (rent-plot (plot-id uint))
    (let (
        (plot-info (unwrap! (map-get? plots plot-id) (err err-invalid-plot)))
        (current-owner (get owner plot-info))
    )
    (asserts! (is-none current-owner) (err err-plot-taken))
    (try! (stx-transfer? rental-price tx-sender contract-owner))
    (update-user-stats tx-sender)
    (ok (map-set plots plot-id 
        {owner: (some tx-sender), 
         expiry: (+ block-height u52560)})) ;; ~1 year in blocks
    )
)

(define-public (extend-rental (plot-id uint))
    (let (
        (plot-info (unwrap! (map-get? plots plot-id) (err err-invalid-plot)))
        (current-owner (get owner plot-info))
        (discounted-price (calculate-discounted-price))
    )
    (asserts! (is-eq (some tx-sender) current-owner) (err err-not-plot-owner))
    (try! (stx-transfer? discounted-price tx-sender contract-owner))
    (ok (map-set plots plot-id 
        {owner: (some tx-sender),
         expiry: (+ (get expiry plot-info) u52560)}))
    )
)

(define-public (release-plot (plot-id uint))
    (let (
        (plot-info (unwrap! (map-get? plots plot-id) (err err-invalid-plot)))
        (current-owner (get owner plot-info))
    )
    (asserts! (is-eq (some tx-sender) current-owner) (err err-not-plot-owner))
    (ok (map-set plots plot-id 
        {owner: none, 
         expiry: u0}))
    )
)

(define-public (claim-rewards)
    (let (
        (user-info (default-to {total-rentals: u0, rewards: u0} (map-get? user-stats tx-sender)))
        (rewards-amount (get rewards user-info))
    )
    (asserts! (> rewards-amount u0) (err err-insufficient-funds))
    (try! (stx-transfer? rewards-amount contract-owner tx-sender))
    (map-set user-stats tx-sender
        {total-rentals: (get total-rentals user-info),
         rewards: u0})
    (ok rewards-amount)
    )
)

;; Admin functions
(define-public (set-plot-details (plot-id uint) (size uint) (location (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (ok (map-set plot-details plot-id {size: size, location: location}))
    )
)

(define-public (set-rental-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (ok (var-set rental-price new-price))
    )
)

(define-public (set-loyalty-discount (new-discount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (ok (var-set loyalty-discount new-discount))
    )
)

;; Read-only functions
(define-read-only (get-plot-info (plot-id uint))
    (map-get? plots plot-id)
)

(define-read-only (get-plot-details (plot-id uint))
    (map-get? plot-details plot-id)
)

(define-read-only (get-rental-price)
    (ok (var-get rental-price))
)

(define-read-only (get-user-stats (user principal))
    (default-to {total-rentals: u0, rewards: u0} (map-get? user-stats user))
)

(define-read-only (is-plot-available (plot-id uint))
    (let (
        (plot-info (unwrap! (map-get? plots plot-id) (err err-invalid-plot)))
        (current-owner (get owner plot-info))
    )
    (ok (is-none current-owner))
    )
)

;; Private functions
(define-private (update-user-stats (user principal))
    (let (
        (stats (default-to {total-rentals: u0, rewards: u0} (map-get? user-stats user)))
        (new-rentals (+ (get total-rentals stats) u1))
        (new-rewards (+ (get rewards stats) (/ rental-price u10)))
    )
    (map-set user-stats user 
        {total-rentals: new-rentals,
         rewards: new-rewards})
    )
)

(define-private (calculate-discounted-price)
    (let (
        (base-price (var-get rental-price))
        (discount (var-get loyalty-discount))
    )
    (- base-price (/ (* base-price discount) u100))
    )
)
