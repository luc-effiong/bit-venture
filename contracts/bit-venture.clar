;; Title: BitVenture - Decentralized Startup Funding Protocol
;;
;; Summary:
;; A trustless venture capital platform built on Bitcoin's Stacks layer, enabling startups
;; to raise capital through milestone-based funding while investors maintain governance rights
;; through tokenized equity and decentralized voting mechanisms.
;;
;; Description:
;; BitVenture revolutionizes startup funding by combining transparent on-chain fundraising
;; with investor-controlled milestone releases. Founders create campaigns with predefined
;; funding goals and milestones, while investors receive proportional equity tokens that
;; grant voting power over fund disbursements. This creates a trustless environment where
;; capital flows are contingent upon verified progress, protecting investors while enabling
;; entrepreneurs to access Bitcoin-native funding without intermediaries. The protocol
;; features automated equity distribution, milestone-based governance, portfolio tracking,
;; and a sustainable fee model that aligns platform incentives with successful campaigns.

;; Constants - Error Codes

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u102))
(define-constant ERR-CAMPAIGN-ENDED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-PARAMETER (err u105))
(define-constant ERR-MILESTONE-NOT-FOUND (err u106))
(define-constant ERR-ALREADY-VOTED (err u107))
(define-constant ERR-VOTING-PERIOD-ENDED (err u108))
(define-constant ERR-MILESTONE-NOT-COMPLETED (err u109))

;; Data Variables - Platform State

(define-data-var total-campaigns uint u0)
(define-data-var platform-fee-percentage uint u250) ;; 2.5% (250 basis points)
(define-data-var total-platform-fees uint u0)
(define-data-var paused bool false)

;; Data Maps - Campaign Management

;; Core campaign data structure
(define-map campaigns
    uint
    {
        founder: principal,
        title: (string-utf8 64),
        description: (string-utf8 256),
        funding-goal: uint,
        total-raised: uint,
        deadline: uint,
        active: bool,
        completed: bool,
        milestone-count: uint,
    }
)

;; Investment tracking per investor per campaign
(define-map campaign-investments
    {
        campaign-id: uint,
        investor: principal,
    }
    {
        amount: uint,
        timestamp: uint,
        equity-tokens: uint,
    }
)

;; Milestone definitions and voting state
(define-map campaign-milestones
    {
        campaign-id: uint,
        milestone-id: uint,
    }
    {
        title: (string-utf8 64),
        description: (string-utf8 256),
        funding-percentage: uint,
        completed: bool,
        votes-for: uint,
        votes-against: uint,
        voting-deadline: uint,
        funds-released: bool,
    }
)

;; Individual milestone vote records
(define-map milestone-votes
    {
        campaign-id: uint,
        milestone-id: uint,
        voter: principal,
    }
    {
        vote: bool, ;; true = approve, false = reject
        timestamp: uint,
        voting-power: uint,
    }
)

;; Aggregated investor portfolio data
(define-map investor-portfolios
    principal
    {
        total-invested: uint,
        active-campaigns: uint,
        total-returns: uint,
    }
)

;; Campaign performance metrics
(define-map campaign-stats
    uint
    {
        total-investors: uint,
        average-investment: uint,
        last-update: uint,
    }
)

;; Read-Only Functions - Campaign Queries

(define-read-only (get-campaign-details (campaign-id uint))
    (map-get? campaigns campaign-id)
)

(define-read-only (get-investment-details
        (campaign-id uint)
        (investor principal)
    )
    (map-get? campaign-investments {
        campaign-id: campaign-id,
        investor: investor,
    })
)

(define-read-only (get-total-campaigns)
    (var-get total-campaigns)
)

(define-read-only (get-platform-fee-percentage)
    (var-get platform-fee-percentage)
)

(define-read-only (is-contract-paused)
    (var-get paused)
)

;; Read-Only Functions - Milestone Queries

(define-read-only (get-milestone-details
        (campaign-id uint)
        (milestone-id uint)
    )
    (map-get? campaign-milestones {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
    })
)

(define-read-only (get-milestone-vote
        (campaign-id uint)
        (milestone-id uint)
        (voter principal)
    )
    (map-get? milestone-votes {
        campaign-id: campaign-id,
        milestone-id: milestone-id,
        voter: voter,
    })
)

(define-read-only (calculate-milestone-approval-rate
        (campaign-id uint)
        (milestone-id uint)
    )
    (let (
            (milestone (unwrap!
                (map-get? campaign-milestones {
                    campaign-id: campaign-id,
                    milestone-id: milestone-id,
                })
                (err u0)
            ))
        )
        (let (
                (total-votes (+ (get votes-for milestone) (get votes-against milestone)))
            )
            (if (> total-votes u0)
                (ok (/ (* (get votes-for milestone) u100) total-votes))
                (ok u0)
            )
        )
    )
)

;; Read-Only Functions - Portfolio & Stats

(define-read-only (get-investor-portfolio (investor principal))
    (map-get? investor-portfolios investor)
)

(define-read-only (get-campaign-stats (campaign-id uint))
    (map-get? campaign-stats campaign-id)
)

;; Private Functions - Calculations

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-percentage)) u10000)
)

(define-private (calculate-equity-tokens
        (investment uint)
        (funding-goal uint)
    )
    ;; Equity calculation: (investment / funding-goal) * 10000 basis points
    (/ (* investment u10000) funding-goal)
)

;; Public Functions - Campaign Creation

(define-public (create-campaign
        (title (string-utf8 64))
        (description (string-utf8 256))
        (funding-goal uint)
        (duration uint)
        (milestone-count uint)
    )
    (let (
            (campaign-id (+ (var-get total-campaigns) u1))
        )
        (begin
            (asserts! (not (var-get paused)) ERR-INVALID-PARAMETER)
            (asserts! (> funding-goal u0) ERR-INVALID-PARAMETER)
            (asserts! (> duration u0) ERR-INVALID-PARAMETER)
            (asserts! (and (>= milestone-count u1) (<= milestone-count u10))
                ERR-INVALID-PARAMETER
            )
            
            (map-set campaigns campaign-id {
                founder: tx-sender,
                title: title,
                description: description,
                funding-goal: funding-goal,
                total-raised: u0,
                deadline: (+ stacks-block-height duration),
                active: true,
                completed: false,
                milestone-count: milestone-count,
            })
            
            (map-set campaign-stats campaign-id {
                total-investors: u0,
                average-investment: u0,
                last-update: stacks-block-height,
            })
            
            (var-set total-campaigns campaign-id)
            (ok campaign-id)
        )
    )
)

;; Public Functions - Investment Flow

(define-public (invest-in-campaign
        (campaign-id uint)
        (amount uint)
    )
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
            (existing-investment (default-to {
                amount: u0,
                timestamp: u0,
                equity-tokens: u0,
            }
                (map-get? campaign-investments {
                    campaign-id: campaign-id,
                    investor: tx-sender,
                })
            ))
            (platform-fee (calculate-platform-fee amount))
            (investment-amount (- amount platform-fee))
            (equity-tokens (calculate-equity-tokens investment-amount
                (get funding-goal campaign)
            ))
        )
        (begin
            (asserts! (not (var-get paused)) ERR-INVALID-PARAMETER)
            (asserts! (get active campaign) ERR-CAMPAIGN-ENDED)
            (asserts! (<= stacks-block-height (get deadline campaign))
                ERR-CAMPAIGN-ENDED
            )
            (asserts! (> amount u0) ERR-INVALID-PARAMETER)
            (asserts! (>= (stx-get-balance tx-sender) amount)
                ERR-INSUFFICIENT-FUNDS
            )
            
            ;; Transfer investment to founder
            (unwrap!
                (stx-transfer? investment-amount tx-sender (get founder campaign))
                ERR-INSUFFICIENT-FUNDS
            )
            
            ;; Transfer platform fee
            (unwrap! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER)
                ERR-INSUFFICIENT-FUNDS
            )
            
            ;; Update campaign total raised
            (map-set campaigns campaign-id
                (merge campaign { total-raised: (+ (get total-raised campaign) investment-amount) })
            )
            
            ;; Update investment record
            (map-set campaign-investments {
                campaign-id: campaign-id,
                investor: tx-sender,
            } {
                amount: (+ (get amount existing-investment) investment-amount),
                timestamp: stacks-block-height,
                equity-tokens: (+ (get equity-tokens existing-investment) equity-tokens),
            })
            
            ;; Update investor portfolio
            (let (
                    (portfolio (default-to {
                        total-invested: u0,
                        active-campaigns: u0,
                        total-returns: u0,
                    }
                        (map-get? investor-portfolios tx-sender)
                    ))
                )
                (map-set investor-portfolios tx-sender
                    (merge portfolio {
                        total-invested: (+ (get total-invested portfolio) investment-amount),
                        active-campaigns: (if (is-eq (get amount existing-investment) u0)
                            (+ (get active-campaigns portfolio) u1)
                            (get active-campaigns portfolio)
                        ),
                    })
                )
            )
            
            ;; Update campaign statistics
            (let (
                    (current-stats (default-to {
                        total-investors: u0,
                        average-investment: u0,
                        last-update: u0,
                    }
                        (map-get? campaign-stats campaign-id)
                    ))
                )
                (let (
                        (new-investor-count (if (is-eq (get amount existing-investment) u0)
                            (+ (get total-investors current-stats) u1)
                            (get total-investors current-stats)
                        ))
                    )
                    (map-set campaign-stats campaign-id {
                        total-investors: new-investor-count,
                        average-investment: (/ (+ (get total-raised campaign) investment-amount)
                            new-investor-count
                        ),
                        last-update: stacks-block-height,
                    })
                )
            )
            
            ;; Update platform fees
            (var-set total-platform-fees
                (+ (var-get total-platform-fees) platform-fee)
            )
            
            (ok true)
        )
    )
)

(define-public (close-campaign (campaign-id uint))
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        )
        (begin
            (asserts! (is-eq tx-sender (get founder campaign)) ERR-NOT-AUTHORIZED)
            (asserts! (get active campaign) ERR-CAMPAIGN-ENDED)
            (asserts!
                (or
                    (> stacks-block-height (get deadline campaign))
                    (>= (get total-raised campaign) (get funding-goal campaign))
                )
                ERR-INVALID-PARAMETER
            )
            
            (map-set campaigns campaign-id
                (merge campaign {
                    active: false,
                    completed: true,
                })
            )
            
            (ok true)
        )
    )
)

;; Public Functions - Milestone Management

(define-public (create-milestone
        (campaign-id uint)
        (milestone-id uint)
        (title (string-utf8 64))
        (description (string-utf8 256))
        (funding-percentage uint)
        (voting-duration uint)
    )
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        )
        (begin
            (asserts! (is-eq tx-sender (get founder campaign)) ERR-NOT-AUTHORIZED)
            (asserts! (get completed campaign) ERR-CAMPAIGN-NOT-FOUND)
            (asserts! (<= milestone-id (get milestone-count campaign))
                ERR-INVALID-PARAMETER
            )
            (asserts!
                (and (> funding-percentage u0) (<= funding-percentage u100))
                ERR-INVALID-PARAMETER
            )
            
            (map-set campaign-milestones {
                campaign-id: campaign-id,
                milestone-id: milestone-id,
            } {
                title: title,
                description: description,
                funding-percentage: funding-percentage,
                completed: false,
                votes-for: u0,
                votes-against: u0,
                voting-deadline: (+ stacks-block-height voting-duration),
                funds-released: false,
            })
            
            (ok true)
        )
    )
)

;; Public Functions - Milestone Voting

(define-public (vote-on-milestone
        (campaign-id uint)
        (milestone-id uint)
        (approve bool)
    )
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
            (milestone (unwrap!
                (map-get? campaign-milestones {
                    campaign-id: campaign-id,
                    milestone-id: milestone-id,
                })
                ERR-MILESTONE-NOT-FOUND
            ))
            (investment (unwrap!
                (map-get? campaign-investments {
                    campaign-id: campaign-id,
                    investor: tx-sender,
                })
                ERR-NOT-AUTHORIZED
            ))
            (existing-vote (map-get? milestone-votes {
                campaign-id: campaign-id,
                milestone-id: milestone-id,
                voter: tx-sender,
            }))
            (voting-power (get equity-tokens investment))
        )
        (begin
            (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
            (asserts! (<= stacks-block-height (get voting-deadline milestone))
                ERR-VOTING-PERIOD-ENDED
            )
            (asserts! (> voting-power u0) ERR-NOT-AUTHORIZED)
            
            ;; Record vote
            (map-set milestone-votes {
                campaign-id: campaign-id,
                milestone-id: milestone-id,
                voter: tx-sender,
            } {
                vote: approve,
                timestamp: stacks-block-height,
                voting-power: voting-power,
            })
            
            ;; Update milestone vote counts
            (map-set campaign-milestones {
                campaign-id: campaign-id,
                milestone-id: milestone-id,
            }
                (merge milestone {
                    votes-for: (if approve
                        (+ (get votes-for milestone) voting-power)
                        (get votes-for milestone)
                    ),
                    votes-against: (if (not approve)
                        (+ (get votes-against milestone) voting-power)
                        (get votes-against milestone)
                    ),
                })
            )
            
            (ok true)
        )
    )
)

(define-public (complete-milestone
        (campaign-id uint)
        (milestone-id uint)
    )
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
            (milestone (unwrap!
                (map-get? campaign-milestones {
                    campaign-id: campaign-id,
                    milestone-id: milestone-id,
                })
                ERR-MILESTONE-NOT-FOUND
            ))
            (total-votes (+ (get votes-for milestone) (get votes-against milestone)))
            (approval-rate (if (> total-votes u0)
                (/ (* (get votes-for milestone) u100) total-votes)
                u0
            ))
        )
        (begin
            (asserts! (is-eq tx-sender (get founder campaign)) ERR-NOT-AUTHORIZED)
            (asserts! (> stacks-block-height (get voting-deadline milestone))
                ERR-VOTING-PERIOD-ENDED
            )
            (asserts! (>= approval-rate u51) ERR-MILESTONE-NOT-COMPLETED) ;; Require >50% approval
            (asserts! (not (get funds-released milestone)) ERR-INVALID-PARAMETER)
            
            ;; Mark milestone as completed and funds released
            (map-set campaign-milestones {
                campaign-id: campaign-id,
                milestone-id: milestone-id,
            }
                (merge milestone {
                    completed: true,
                    funds-released: true,
                })
            )
            
            (ok true)
        )
    )
)

;; Public Functions - Platform Administration

(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (<= new-fee u1000) ERR-INVALID-PARAMETER) ;; Maximum 10% fee
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-public (toggle-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set paused (not (var-get paused)))
        (ok true)
    )
)

(define-public (withdraw-platform-fees)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (let (
                (fees (var-get total-platform-fees))
            )
            (var-set total-platform-fees u0)
            (stx-transfer? fees tx-sender CONTRACT-OWNER)
        )
    )
)

;; Public Functions - Emergency Controls

(define-public (emergency-close-campaign (campaign-id uint))
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        )
        (begin
            (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
            (map-set campaigns campaign-id (merge campaign { active: false }))
            (ok true)
        )
    )
)

(define-public (force-milestone-completion
        (campaign-id uint)
        (milestone-id uint)
    )
    (let (
            (milestone (unwrap!
                (map-get? campaign-milestones {
                    campaign-id: campaign-id,
                    milestone-id: milestone-id,
                })
                ERR-MILESTONE-NOT-FOUND
            ))
        )
        (begin
            (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
            (map-set campaign-milestones {
                campaign-id: campaign-id,
                milestone-id: milestone-id,
            }
                (merge milestone {
                    completed: true,
                    funds-released: true,
                })
            )
            (ok true)
        )
    )
)