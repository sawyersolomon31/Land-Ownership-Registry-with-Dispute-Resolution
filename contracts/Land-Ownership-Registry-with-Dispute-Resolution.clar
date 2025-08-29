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

(define-constant ERR_AUCTION_NOT_FOUND (err u109))
(define-constant ERR_AUCTION_ENDED (err u110))
(define-constant ERR_BID_TOO_LOW (err u111))
(define-constant ERR_AUCTION_ACTIVE (err u112))

(define-data-var auction-id-counter uint u0)

(define-map land-auctions
  uint
  {
    land-id: uint,
    seller: principal,
    starting-price: uint,
    current-bid: uint,
    highest-bidder: (optional principal),
    end-block: uint,
    is-active: bool
  }
)

(define-map auction-bids
  {auction-id: uint, bidder: principal}
  uint
)

(define-public (create-auction (land-id uint) (starting-price uint) (duration uint))
  (let ((new-auction-id (+ (var-get auction-id-counter) u1)))
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (asserts! (is-eq tx-sender (get owner land-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-verified land-data) ERR_NOT_AUTHORIZED)
        (map-set land-auctions new-auction-id
          {
            land-id: land-id,
            seller: tx-sender,
            starting-price: starting-price,
            current-bid: starting-price,
            highest-bidder: none,
            end-block: (+ stacks-block-height duration),
            is-active: true
          }
        )
        (var-set auction-id-counter new-auction-id)
        (ok new-auction-id)
      )
      ERR_LAND_NOT_FOUND
    )
  )
)

(define-public (place-bid (auction-id uint) (bid-amount uint))
  (match (map-get? land-auctions auction-id)
    auction-data
    (begin
      (asserts! (get is-active auction-data) ERR_AUCTION_ENDED)
      (asserts! (< stacks-block-height (get end-block auction-data)) ERR_AUCTION_ENDED)
      (asserts! (> bid-amount (get current-bid auction-data)) ERR_BID_TOO_LOW)
      (asserts! (>= (stx-get-balance tx-sender) bid-amount) ERR_INSUFFICIENT_STAKE)
      
      (match (get highest-bidder auction-data)
        previous-bidder
        (let ((previous-bid (get current-bid auction-data)))
          (try! (as-contract (stx-transfer? previous-bid tx-sender previous-bidder)))
        )
        true
      )
      
      (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
      
      (map-set land-auctions auction-id
        (merge auction-data
          {
            current-bid: bid-amount,
            highest-bidder: (some tx-sender)
          }
        )
      )
      (map-set auction-bids {auction-id: auction-id, bidder: tx-sender} bid-amount)
      (ok true)
    )
    ERR_AUCTION_NOT_FOUND
  )
)

(define-public (finalize-auction (auction-id uint))
  (match (map-get? land-auctions auction-id)
    auction-data
    (begin
      (asserts! (get is-active auction-data) ERR_AUCTION_ENDED)
      (asserts! (>= stacks-block-height (get end-block auction-data)) ERR_AUCTION_ACTIVE)
      
      (match (get highest-bidder auction-data)
        winner
        (match (map-get? land-registry (get land-id auction-data))
          land-data
          (begin
            (try! (as-contract (stx-transfer? (get current-bid auction-data) tx-sender (get seller auction-data))))
            (map-set land-registry (get land-id auction-data) (merge land-data {owner: winner}))
            (map-set land-auctions auction-id (merge auction-data {is-active: false}))
            (ok true)
          )
          ERR_LAND_NOT_FOUND
        )
        (begin
          (map-set land-auctions auction-id (merge auction-data {is-active: false}))
          (ok false)
        )
      )
    )
    ERR_AUCTION_NOT_FOUND
  )
)

(define-read-only (get-auction-info (auction-id uint))
  (map-get? land-auctions auction-id)
)

(define-read-only (get-auction-count)
  (var-get auction-id-counter)
)

(define-data-var history-id-counter uint u0)

(define-map land-history
  uint
  {
    land-id: uint,
    event-type: (string-ascii 20),
    from-owner: (optional principal),
    to-owner: (optional principal),
    timestamp: uint,
    block-height: uint,
    additional-data: (string-ascii 200)
  }
)

(define-map land-history-index
  uint
  (list 50 uint)
)

(define-private (add-history-entry (land-id uint) (event-type (string-ascii 20)) (from-owner (optional principal)) (to-owner (optional principal)) (additional-data (string-ascii 200)))
  (let ((new-history-id (+ (var-get history-id-counter) u1))
        (current-history (default-to (list) (map-get? land-history-index land-id))))
    (map-set land-history new-history-id
      {
        land-id: land-id,
        event-type: event-type,
        from-owner: from-owner,
        to-owner: to-owner,
        timestamp: stacks-block-height,
        block-height: stacks-block-height,
        additional-data: additional-data
      }
    )
    (map-set land-history-index land-id (unwrap-panic (as-max-len? (append current-history new-history-id) u50)))
    (var-set history-id-counter new-history-id)
    new-history-id
  )
)

(define-public (register-land-with-history (size uint) (gps-coordinates (string-ascii 100)) (document-hash (string-ascii 64)))
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
    (add-history-entry new-land-id "registration" none (some tx-sender) "Initial land registration")
    (ok new-land-id)
  )
)

(define-public (complete-transfer-with-history (land-id uint))
  (match (map-get? land-transfers land-id)
    transfer-data
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (asserts! (is-eq tx-sender (get notary transfer-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-completed transfer-data)) ERR_INVALID_TRANSFER)
        (map-set land-registry land-id (merge land-data {owner: (get to transfer-data)}))
        (map-set land-transfers land-id (merge transfer-data {is-completed: true}))
        (add-history-entry land-id "transfer" (some (get from transfer-data)) (some (get to transfer-data)) "Notarized transfer completed")
        (ok true)
      )
      ERR_LAND_NOT_FOUND
    )
    ERR_INVALID_TRANSFER
  )
)

(define-public (verify-land-with-history (land-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (map-set land-registry land-id (merge land-data {is-verified: true}))
        (add-history-entry land-id "verification" none (some (get owner land-data)) "Land ownership verified by authority")
        (ok true)
      )
      ERR_LAND_NOT_FOUND
    )
  )
)

(define-public (add-land-annotation (land-id uint) (annotation (string-ascii 200)))
  (match (map-get? land-registry land-id)
    land-data
    (begin
      (asserts! (is-eq tx-sender (get owner land-data)) ERR_NOT_AUTHORIZED)
      (add-history-entry land-id "annotation" (some tx-sender) (some tx-sender) annotation)
      (ok true)
    )
    ERR_LAND_NOT_FOUND
  )
)

(define-read-only (get-land-history (land-id uint))
  (map-get? land-history-index land-id)
)

(define-read-only (get-history-entry (history-id uint))
  (map-get? land-history history-id)
)

(define-read-only (get-land-ownership-chain (land-id uint))
  (match (map-get? land-history-index land-id)
    history-ids
    (some (map get-history-entry history-ids))
    none
  )
)

(define-read-only (get-history-count)
  (var-get history-id-counter)
)

(define-constant ERR_RENTAL_NOT_FOUND (err u113))
(define-constant ERR_RENTAL_EXPIRED (err u114))
(define-constant ERR_PAYMENT_OVERDUE (err u115))
(define-constant ERR_RENTAL_ACTIVE (err u116))

(define-data-var rental-id-counter uint u0)

(define-map land-rentals
  uint
  {
    land-id: uint,
    landlord: principal,
    tenant: principal,
    monthly-rent: uint,
    deposit: uint,
    start-block: uint,
    end-block: uint,
    last-payment-block: uint,
    is-active: bool
  }
)

(define-map rental-payments
  {rental-id: uint, payment-id: uint}
  {
    amount: uint,
    timestamp: uint,
    block-height: uint
  }
)

(define-public (create-rental (land-id uint) (tenant principal) (monthly-rent uint) (deposit uint) (duration-blocks uint))
  (let ((new-rental-id (+ (var-get rental-id-counter) u1)))
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (asserts! (is-eq tx-sender (get owner land-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-verified land-data) ERR_NOT_AUTHORIZED)
        (map-set land-rentals new-rental-id
          {
            land-id: land-id,
            landlord: tx-sender,
            tenant: tenant,
            monthly-rent: monthly-rent,
            deposit: deposit,
            start-block: stacks-block-height,
            end-block: (+ stacks-block-height duration-blocks),
            last-payment-block: stacks-block-height,
            is-active: true
          }
        )
        (var-set rental-id-counter new-rental-id)
        (ok new-rental-id)
      )
      ERR_LAND_NOT_FOUND
    )
  )
)

(define-public (pay-rent (rental-id uint))
  (match (map-get? land-rentals rental-id)
    rental-data
    (begin
      (asserts! (is-eq tx-sender (get tenant rental-data)) ERR_NOT_AUTHORIZED)
      (asserts! (get is-active rental-data) ERR_RENTAL_EXPIRED)
      (asserts! (< stacks-block-height (get end-block rental-data)) ERR_RENTAL_EXPIRED)
      (asserts! (>= (stx-get-balance tx-sender) (get monthly-rent rental-data)) ERR_INSUFFICIENT_STAKE)
      
      (try! (stx-transfer? (get monthly-rent rental-data) tx-sender (get landlord rental-data)))
      
      (map-set land-rentals rental-id
        (merge rental-data {last-payment-block: stacks-block-height})
      )
      
      (map-set rental-payments {rental-id: rental-id, payment-id: stacks-block-height} 
        {
          amount: (get monthly-rent rental-data),
          timestamp: stacks-block-height,
          block-height: stacks-block-height
        }
      )
      (ok true)
    )
    ERR_RENTAL_NOT_FOUND
  )
)

(define-public (pay-deposit (rental-id uint))
  (match (map-get? land-rentals rental-id)
    rental-data
    (begin
      (asserts! (is-eq tx-sender (get tenant rental-data)) ERR_NOT_AUTHORIZED)
      (asserts! (get is-active rental-data) ERR_RENTAL_EXPIRED)
      (asserts! (>= (stx-get-balance tx-sender) (get deposit rental-data)) ERR_INSUFFICIENT_STAKE)
      
      (try! (stx-transfer? (get deposit rental-data) tx-sender (get landlord rental-data)))
      (ok true)
    )
    ERR_RENTAL_NOT_FOUND
  )
)

(define-public (terminate-rental (rental-id uint))
  (match (map-get? land-rentals rental-id)
    rental-data
    (begin
      (asserts! (or (is-eq tx-sender (get landlord rental-data)) (is-eq tx-sender (get tenant rental-data))) ERR_NOT_AUTHORIZED)
      (map-set land-rentals rental-id (merge rental-data {is-active: false}))
      (ok true)
    )
    ERR_RENTAL_NOT_FOUND
  )
)

(define-read-only (get-rental-info (rental-id uint))
  (map-get? land-rentals rental-id)
)

(define-read-only (get-rental-payment (rental-id uint) (payment-id uint))
  (map-get? rental-payments {rental-id: rental-id, payment-id: payment-id})
)

(define-read-only (is-rent-overdue (rental-id uint) (blocks-per-month uint))
  (match (map-get? land-rentals rental-id)
    rental-data
    (if (get is-active rental-data)
      (> (- stacks-block-height (get last-payment-block rental-data)) blocks-per-month)
      false
    )
    false
  )
)

(define-read-only (get-rental-count)
  (var-get rental-id-counter)
)

(define-constant ERR_POLICY_NOT_FOUND (err u117))
(define-constant ERR_POLICY_EXPIRED (err u118))
(define-constant ERR_CLAIM_NOT_FOUND (err u119))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u120))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u121))
(define-constant ERR_PREMIUM_OVERDUE (err u122))

(define-data-var policy-id-counter uint u0)
(define-data-var claim-id-counter uint u0)
(define-data-var insurance-pool uint u0)

(define-map insurance-policies
  uint
  {
    land-id: uint,
    policyholder: principal,
    coverage-amount: uint,
    annual-premium: uint,
    start-block: uint,
    end-block: uint,
    last-premium-payment: uint,
    is-active: bool
  }
)

(define-map insurance-claims
  uint
  {
    policy-id: uint,
    claimant: principal,
    damage-description: (string-ascii 500),
    claim-amount: uint,
    assessor: (optional principal),
    status: (string-ascii 20),
    filed-at: uint,
    processed-at: (optional uint)
  }
)

(define-map insurance-assessors
  principal
  {
    reputation-score: uint,
    total-claims-assessed: uint,
    is-active: bool
  }
)

(define-public (register-assessor)
  (begin
    (map-set insurance-assessors tx-sender
      {
        reputation-score: u100,
        total-claims-assessed: u0,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (purchase-policy (land-id uint) (coverage-amount uint) (annual-premium uint) (duration-blocks uint))
  (let ((new-policy-id (+ (var-get policy-id-counter) u1)))
    (match (map-get? land-registry land-id)
      land-data
      (begin
        (asserts! (is-eq tx-sender (get owner land-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-verified land-data) ERR_NOT_AUTHORIZED)
        (asserts! (>= (stx-get-balance tx-sender) annual-premium) ERR_INSUFFICIENT_STAKE)
        
        (try! (stx-transfer? annual-premium tx-sender (as-contract tx-sender)))
        (var-set insurance-pool (+ (var-get insurance-pool) annual-premium))
        
        (map-set insurance-policies new-policy-id
          {
            land-id: land-id,
            policyholder: tx-sender,
            coverage-amount: coverage-amount,
            annual-premium: annual-premium,
            start-block: stacks-block-height,
            end-block: (+ stacks-block-height duration-blocks),
            last-premium-payment: stacks-block-height,
            is-active: true
          }
        )
        (var-set policy-id-counter new-policy-id)
        (ok new-policy-id)
      )
      ERR_LAND_NOT_FOUND
    )
  )
)

(define-public (pay-premium (policy-id uint))
  (match (map-get? insurance-policies policy-id)
    policy-data
    (begin
      (asserts! (is-eq tx-sender (get policyholder policy-data)) ERR_NOT_AUTHORIZED)
      (asserts! (get is-active policy-data) ERR_POLICY_EXPIRED)
      (asserts! (< stacks-block-height (get end-block policy-data)) ERR_POLICY_EXPIRED)
      (asserts! (>= (stx-get-balance tx-sender) (get annual-premium policy-data)) ERR_INSUFFICIENT_STAKE)
      
      (try! (stx-transfer? (get annual-premium policy-data) tx-sender (as-contract tx-sender)))
      (var-set insurance-pool (+ (var-get insurance-pool) (get annual-premium policy-data)))
      
      (map-set insurance-policies policy-id
        (merge policy-data {last-premium-payment: stacks-block-height})
      )
      (ok true)
    )
    ERR_POLICY_NOT_FOUND
  )
)

(define-public (file-claim (policy-id uint) (damage-description (string-ascii 500)) (claim-amount uint))
  (let ((new-claim-id (+ (var-get claim-id-counter) u1)))
    (match (map-get? insurance-policies policy-id)
      policy-data
      (begin
        (asserts! (is-eq tx-sender (get policyholder policy-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active policy-data) ERR_POLICY_EXPIRED)
        (asserts! (< stacks-block-height (get end-block policy-data)) ERR_POLICY_EXPIRED)
        (asserts! (<= claim-amount (get coverage-amount policy-data)) ERR_INSUFFICIENT_COVERAGE)
        
        (map-set insurance-claims new-claim-id
          {
            policy-id: policy-id,
            claimant: tx-sender,
            damage-description: damage-description,
            claim-amount: claim-amount,
            assessor: none,
            status: "pending",
            filed-at: stacks-block-height,
            processed-at: none
          }
        )
        (var-set claim-id-counter new-claim-id)
        (ok new-claim-id)
      )
      ERR_POLICY_NOT_FOUND
    )
  )
)

(define-public (assess-claim (claim-id uint) (approved bool))
  (match (map-get? insurance-assessors tx-sender)
    assessor-data
    (match (map-get? insurance-claims claim-id)
      claim-data
      (begin
        (asserts! (get is-active assessor-data) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status claim-data) "pending") ERR_CLAIM_ALREADY_PROCESSED)
        
        (if approved
          (begin
            (asserts! (>= (var-get insurance-pool) (get claim-amount claim-data)) ERR_INSUFFICIENT_COVERAGE)
            (try! (as-contract (stx-transfer? (get claim-amount claim-data) tx-sender (get claimant claim-data))))
            (var-set insurance-pool (- (var-get insurance-pool) (get claim-amount claim-data)))
            (map-set insurance-claims claim-id
              (merge claim-data 
                {
                  assessor: (some tx-sender),
                  status: "approved",
                  processed-at: (some stacks-block-height)
                }
              )
            )
          )
          (map-set insurance-claims claim-id
            (merge claim-data 
              {
                assessor: (some tx-sender),
                status: "rejected",
                processed-at: (some stacks-block-height)
              }
            )
          )
        )
        
        (map-set insurance-assessors tx-sender
          (merge assessor-data 
            {
              total-claims-assessed: (+ (get total-claims-assessed assessor-data) u1)
            }
          )
        )
        (ok true)
      )
      ERR_CLAIM_NOT_FOUND
    )
    ERR_NOT_AUTHORIZED
  )
)

(define-public (cancel-policy (policy-id uint))
  (match (map-get? insurance-policies policy-id)
    policy-data
    (begin
      (asserts! (is-eq tx-sender (get policyholder policy-data)) ERR_NOT_AUTHORIZED)
      (map-set insurance-policies policy-id (merge policy-data {is-active: false}))
      (ok true)
    )
    ERR_POLICY_NOT_FOUND
  )
)

(define-read-only (get-policy-info (policy-id uint))
  (map-get? insurance-policies policy-id)
)

(define-read-only (get-claim-info (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (get-assessor-info (assessor principal))
  (map-get? insurance-assessors assessor)
)

(define-read-only (get-insurance-pool-balance)
  (var-get insurance-pool)
)

(define-read-only (is-premium-overdue (policy-id uint) (blocks-per-year uint))
  (match (map-get? insurance-policies policy-id)
    policy-data
    (if (get is-active policy-data)
      (> (- stacks-block-height (get last-premium-payment policy-data)) blocks-per-year)
      false
    )
    false
  )
)

(define-read-only (get-policy-count)
  (var-get policy-id-counter)
)

(define-read-only (get-claim-count)
  (var-get claim-id-counter)
)