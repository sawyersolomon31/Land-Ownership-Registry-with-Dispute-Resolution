(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LAND_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_TRANSFER (err u103))
(define-constant ERR_DISPUTE_EXISTS (err u104))
(define-constant ERR_DISPUTE_NOT_FOUND (err u105))
(define-constant ERR_ALREADY_VOTED (err u106))
(define-constant ERR_INSUFFICIENT_STAKE (err u107))

(define-data-var land-id-counter uint u0)
(define-data-var dispute-id-counter uint u0)
(define-data-var min-arbitrator-stake uint u1000)

(define-map land-registry
  uint
  {
    owner: principal,
    size: uint,
    gps-coordinates: (string-ascii 100),
    document-hash: (string-ascii 64),
    is-verified: bool,
    created-at: uint
  }
)

(define-map land-transfers
  uint
  {
    from: principal,
    to: principal,
    notary: principal,
    timestamp: uint,
    is-completed: bool
  }
)

(define-map disputes
  uint
  {
    land-id: uint,
    complainant: principal,
    respondent: principal,
    description: (string-ascii 500),
    status: (string-ascii 20),
    created-at: uint,
    votes-for: uint,
    votes-against: uint
  }
)

(define-map arbitrators
  principal
  {
    stake: uint,
    reputation: uint,
    is-active: bool
  }
)

(define-map dispute-votes
  {dispute-id: uint, voter: principal}
  {vote: bool, timestamp: uint}
)

(define-map notaries principal bool)

(define-public (register-land (size uint) (gps-coordinates (string-ascii 100)) (document-hash (string-ascii 64)))
  (let ((new-land-id (+ (var-get land-id-counter) u1)))
    (map-set land-registry new-land-id
      {
        owner: tx-sender,
        size: size,
        gps-coordinates: gps-coordinates,
        document-hash: document-hash,
        is-verified: false,
        created-at: stacks-block-height
      }
    )
    (var-set land-id-counter new-land-id)
    (ok new-land-id)
  )
)

(define-public (verify-land (land-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (map-set land-registry land-id (merge land-data {is-verified: true}))
        (ok true)
      )
      ERR_LAND_NOT_FOUND
    )
  )
)

(define-public (add-notary (notary principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set notaries notary true)
    (ok true)
  )
)

(define-public (initiate-transfer (land-id uint) (to principal) (notary principal))
  (match (map-get? land-registry land-id)
    land-data
    (begin
      (asserts! (is-eq tx-sender (get owner land-data)) ERR_NOT_AUTHORIZED)
      (asserts! (default-to false (map-get? notaries notary)) ERR_NOT_AUTHORIZED)
      (map-set land-transfers land-id
        {
          from: tx-sender,
          to: to,
          notary: notary,
          timestamp: stacks-block-height,
          is-completed: false
        }
      )
      (ok true)
    )
    ERR_LAND_NOT_FOUND
  )
)

(define-public (complete-transfer (land-id uint))
  (match (map-get? land-transfers land-id)
    transfer-data
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (asserts! (is-eq tx-sender (get notary transfer-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-completed transfer-data)) ERR_INVALID_TRANSFER)
        (map-set land-registry land-id (merge land-data {owner: (get to transfer-data)}))
        (map-set land-transfers land-id (merge transfer-data {is-completed: true}))
        (ok true)
      )
      ERR_LAND_NOT_FOUND
    )
    ERR_INVALID_TRANSFER
  )
)

(define-public (register-arbitrator)
  (begin
    (asserts! (>= (stx-get-balance tx-sender) (var-get min-arbitrator-stake)) ERR_INSUFFICIENT_STAKE)
    (try! (stx-transfer? (var-get min-arbitrator-stake) tx-sender (as-contract tx-sender)))
    (map-set arbitrators tx-sender
      {
        stake: (var-get min-arbitrator-stake),
        reputation: u100,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (file-dispute (land-id uint) (respondent principal) (description (string-ascii 500)))
  (let ((new-dispute-id (+ (var-get dispute-id-counter) u1)))
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (map-set disputes new-dispute-id
          {
            land-id: land-id,
            complainant: tx-sender,
            respondent: respondent,
            description: description,
            status: "pending",
            created-at: stacks-block-height,
            votes-for: u0,
            votes-against: u0
          }
        )
        (var-set dispute-id-counter new-dispute-id)
        (ok new-dispute-id)
      )
      ERR_LAND_NOT_FOUND
    )
  )
)

(define-public (vote-on-dispute (dispute-id uint) (vote bool))
  (match (map-get? arbitrators tx-sender)
    arbitrator-data
    (match (map-get? disputes dispute-id)
      dispute-data
      (begin
        (asserts! (get is-active arbitrator-data) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (map-get? dispute-votes {dispute-id: dispute-id, voter: tx-sender})) ERR_ALREADY_VOTED)
        (map-set dispute-votes {dispute-id: dispute-id, voter: tx-sender} {vote: vote, timestamp: stacks-block-height})
        (if vote
          (map-set disputes dispute-id (merge dispute-data {votes-for: (+ (get votes-for dispute-data) u1)}))
          (map-set disputes dispute-id (merge dispute-data {votes-against: (+ (get votes-against dispute-data) u1)}))
        )
        (ok true)
      )
      ERR_DISPUTE_NOT_FOUND
    )
    ERR_NOT_AUTHORIZED
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (match (map-get? disputes dispute-id)
    dispute-data
    (let ((total-votes (+ (get votes-for dispute-data) (get votes-against dispute-data))))
      (begin
        (asserts! (>= total-votes u3) (err u108))
        (if (> (get votes-for dispute-data) (get votes-against dispute-data))
          (map-set disputes dispute-id (merge dispute-data {status: "resolved-for"}))
          (map-set disputes dispute-id (merge dispute-data {status: "resolved-against"}))
        )
        (ok true)
      )
    )
    ERR_DISPUTE_NOT_FOUND
  )
)

(define-read-only (get-land-info (land-id uint))
  (map-get? land-registry land-id)
)

(define-read-only (get-land-owner (land-id uint))
  (match (map-get? land-registry land-id)
    land-data (some (get owner land-data))
    none
  )
)

(define-read-only (get-transfer-info (land-id uint))
  (map-get? land-transfers land-id)
)

(define-read-only (get-dispute-info (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-arbitrator-info (arbitrator principal))
  (map-get? arbitrators arbitrator)
)

(define-read-only (is-notary (address principal))
  (default-to false (map-get? notaries address))
)

(define-read-only (get-land-count)
  (var-get land-id-counter)
)

(define-read-only (get-dispute-count)
  (var-get dispute-id-counter)
)

