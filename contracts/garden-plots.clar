;; Garden Plot Rental Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-plot-taken (err u101))
(define-constant err-not-plot-owner (err u102))
(define-constant err-invalid-plot (err u103))
(define-constant err-expired (err u104))

;; Data variables
(define-data-var total-plots uint u100)
(define-data-var rental-price uint u100)

;; Data maps
(define-map plots uint {owner: (optional principal), expiry: uint})
(define-map plot-details uint {size: uint, location: (string-ascii 50)})

;; Public functions
(define-public (rent-plot (plot-id uint))
    (let (
        (plot-info (unwrap! (map-get? plots plot-id) (err err-invalid-plot)))
        (current-owner (get owner plot-info))
    )
    (asserts! (is-none current-owner) (err err-plot-taken))
    (try! (stx-transfer? rental-price tx-sender contract-owner))
    (ok (map-set plots plot-id 
        {owner: (some tx-sender), 
         expiry: (+ block-height u52560)})) ;; ~1 year in blocks
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

(define-read-only (is-plot-available (plot-id uint))
    (let (
        (plot-info (unwrap! (map-get? plots plot-id) (err err-invalid-plot)))
        (current-owner (get owner plot-info))
    )
    (ok (is-none current-owner))
    )
)
