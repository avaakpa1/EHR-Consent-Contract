

(define-non-fungible-token ehr-access-key uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_TOKEN_NOT_FOUND (err u102))
(define-constant ERR_UNAUTHORIZED (err u103))
(define-constant ERR_PERMISSION_DENIED (err u104))
(define-constant ERR_TOKEN_EXPIRED (err u105))
(define-constant ERR_INVALID_PERMISSION (err u106))
(define-constant ERR_INVALID_DURATION (err u107))
(define-constant ERR_PATIENT_ONLY (err u108))
(define-constant ERR_HOSPITAL_NOT_REGISTERED (err u109))
(define-constant ERR_ALREADY_EXISTS (err u110))
(define-constant ERR_INVALID_TIME_RANGE (err u111))

(define-data-var last-token-id uint u0)
(define-data-var oracle-address (optional principal) none)

(define-map patient-records
    { patient: principal }
    { ehr-hash: (string-ascii 64), created-at: uint }
)

(define-map access-permissions
    { token-id: uint }
    {
        patient: principal,
        granted-to: principal,
        permission-level: (string-ascii 10),
        expires-at: uint,
        revoked: bool,
        hospital: principal,
        ehr-hash: (string-ascii 64)
    }
)

(define-map hospital-registry
    { hospital: principal }
    { name: (string-ascii 50), verified: bool, registered-at: uint }
)

(define-map patient-consent-history
    { patient: principal, hospital: principal }
    { total-grants: uint, last-granted: uint }
)

(define-map permission-usage
    { token-id: uint }
    { access-count: uint, last-accessed: uint }
)

(define-map patient-analytics
    { patient: principal }
    { total-access-count: uint, unique-hospitals: uint, first-grant: uint, last-access: uint }
)

(define-map hospital-analytics
    { hospital: principal }
    { total-accesses: uint, unique-patients: uint, avg-permission-level: uint, compliance-score: uint }
)

(define-map time-based-analytics
    { time-period: uint, entity: principal }
    { access-count: uint, grant-count: uint, revoke-count: uint }
)

(define-read-only (get-last-token-id)
    (var-get last-token-id)
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? ehr-access-key token-id))
)

(define-read-only (get-patient-record (patient principal))
    (map-get? patient-records { patient: patient })
)

(define-read-only (get-access-permission (token-id uint))
    (map-get? access-permissions { token-id: token-id })
)

(define-read-only (get-hospital-info (hospital principal))
    (map-get? hospital-registry { hospital: hospital })
)

(define-read-only (get-consent-history (patient principal) (hospital principal))
    (map-get? patient-consent-history { patient: patient, hospital: hospital })
)

(define-read-only (get-permission-usage (token-id uint))
    (map-get? permission-usage { token-id: token-id })
)

(define-read-only (get-patient-analytics (patient principal))
    (map-get? patient-analytics { patient: patient })
)

(define-read-only (get-hospital-analytics (hospital principal))
    (map-get? hospital-analytics { hospital: hospital })
)

(define-read-only (get-time-analytics (time-period uint) (entity principal))
    (map-get? time-based-analytics { time-period: time-period, entity: entity })
)

(define-read-only (get-permission-level-score (permission (string-ascii 10)))
    (if (is-eq permission "read")
        u1
        (if (is-eq permission "modify")
            u2
            (if (is-eq permission "admin")
                u3
                u0)))
)

(define-read-only (is-valid-permission (permission (string-ascii 10)))
    (or (is-eq permission "read")
        (or (is-eq permission "modify")
            (is-eq permission "admin")))
)

(define-read-only (has-valid-access (token-id uint) (accessor principal))
    (match (map-get? access-permissions { token-id: token-id })
        permission-data
        (and
            (is-eq (get granted-to permission-data) accessor)
            (not (get revoked permission-data))
            (> (get expires-at permission-data) stacks-block-height)
        )
        false
    )
)

(define-read-only (can-access-ehr (patient principal) (accessor principal) (permission-level (string-ascii 10)))
    (let
        (
            (current-block stacks-block-height)
        )
        (fold check-patient-tokens
            (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
            { patient: patient, accessor: accessor, permission: permission-level, found: false }
        )
    )
)

(define-private (check-patient-tokens (token-id uint) (data { patient: principal, accessor: principal, permission: (string-ascii 10), found: bool }))
    (if (get found data)
        data
        (match (map-get? access-permissions { token-id: token-id })
            permission-data
            (if (and
                    (is-eq (get patient permission-data) (get patient data))
                    (is-eq (get granted-to permission-data) (get accessor data))
                    (not (get revoked permission-data))
                    (> (get expires-at permission-data) stacks-block-height)
                    (or (is-eq (get permission-level permission-data) (get permission data))
                        (is-eq (get permission-level permission-data) "admin"))
                )
                (merge data { found: true })
                data
            )
            data
        )
    )
)

(define-public (register-patient-ehr (ehr-hash (string-ascii 64)))
    (let
        (
            (current-block stacks-block-height)
        )
        (asserts! (is-none (map-get? patient-records { patient: tx-sender })) ERR_ALREADY_EXISTS)
        (map-set patient-records
            { patient: tx-sender }
            { ehr-hash: ehr-hash, created-at: current-block }
        )
        (ok true)
    )
)

(define-public (register-hospital (name (string-ascii 50)))
    (let
        (
            (current-block stacks-block-height)
        )
        (asserts! (is-none (map-get? hospital-registry { hospital: tx-sender })) ERR_ALREADY_EXISTS)
        (map-set hospital-registry
            { hospital: tx-sender }
            { name: name, verified: false, registered-at: current-block }
        )
        (ok true)
    )
)

(define-public (verify-hospital (hospital principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (asserts! (is-some (map-get? hospital-registry { hospital: hospital })) ERR_HOSPITAL_NOT_REGISTERED)
        (map-set hospital-registry
            { hospital: hospital }
            (merge
                (unwrap-panic (map-get? hospital-registry { hospital: hospital }))
                { verified: true }
            )
        )
        (ok true)
    )
)

(define-public (grant-access (to principal) (hospital principal) (permission-level (string-ascii 10)) (duration uint))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (patient-record (unwrap! (map-get? patient-records { patient: tx-sender }) ERR_NOT_TOKEN_OWNER))
            (hospital-data (unwrap! (map-get? hospital-registry { hospital: hospital }) ERR_HOSPITAL_NOT_REGISTERED))
            (current-block stacks-block-height)
            (expires-at (+ current-block duration))
        )
        (asserts! (get verified hospital-data) ERR_HOSPITAL_NOT_REGISTERED)
        (asserts! (is-valid-permission permission-level) ERR_INVALID_PERMISSION)
        (asserts! (> duration u0) ERR_INVALID_DURATION)
        
        (try! (nft-mint? ehr-access-key token-id to))
        
        (map-set access-permissions
            { token-id: token-id }
            {
                patient: tx-sender,
                granted-to: to,
                permission-level: permission-level,
                expires-at: expires-at,
                revoked: false,
                hospital: hospital,
                ehr-hash: (get ehr-hash patient-record)
            }
        )
        
        (map-set permission-usage
            { token-id: token-id }
            { access-count: u0, last-accessed: u0 }
        )
        
        (var-set last-token-id token-id)
        
        (map-set patient-consent-history
            { patient: tx-sender, hospital: hospital }
            (match (map-get? patient-consent-history { patient: tx-sender, hospital: hospital })
                history (merge history { total-grants: (+ (get total-grants history) u1), last-granted: current-block })
                { total-grants: u1, last-granted: current-block }
            )
        )
        
        (update-patient-analytics-on-grant tx-sender hospital current-block)
        (update-hospital-analytics-on-grant hospital tx-sender permission-level)
        (update-time-analytics-on-grant current-block tx-sender)
        
        (ok token-id)
    )
)

(define-public (revoke-access (token-id uint))
    (let
        (
            (permission-data (unwrap! (map-get? access-permissions { token-id: token-id }) ERR_TOKEN_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get patient permission-data)) ERR_PATIENT_ONLY)
        (map-set access-permissions
            { token-id: token-id }
            (merge permission-data { revoked: true })
        )
        (ok true)
    )
)

(define-public (access-ehr-data (token-id uint))
    (let
        (
            (permission-data (unwrap! (map-get? access-permissions { token-id: token-id }) ERR_TOKEN_NOT_FOUND))
            (usage-data (unwrap! (map-get? permission-usage { token-id: token-id }) ERR_TOKEN_NOT_FOUND))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get granted-to permission-data)) ERR_UNAUTHORIZED)
        (asserts! (not (get revoked permission-data)) ERR_PERMISSION_DENIED)
        (asserts! (> (get expires-at permission-data) current-block) ERR_TOKEN_EXPIRED)
        
        (map-set permission-usage
            { token-id: token-id }
            {
                access-count: (+ (get access-count usage-data) u1),
                last-accessed: current-block
            }
        )
        
        (update-patient-analytics-on-access (get patient permission-data) current-block)
        (update-hospital-analytics-on-access (get hospital permission-data))
        (update-time-analytics-on-access current-block (get patient permission-data))
        
        (ok {
            ehr-hash: (get ehr-hash permission-data),
            permission-level: (get permission-level permission-data),
            patient: (get patient permission-data),
            hospital: (get hospital permission-data)
        })
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
        (asserts! (is-some (nft-get-owner? ehr-access-key token-id)) ERR_TOKEN_NOT_FOUND)
        (nft-transfer? ehr-access-key token-id sender recipient)
    )
)

(define-public (set-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (var-set oracle-address (some new-oracle))
        (ok true)
    )
)

(define-public (emergency-revoke-all (patient principal))
    (begin
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender patient)) ERR_UNAUTHORIZED)
        (map-set patient-records
            { patient: patient }
            (merge
                (unwrap-panic (map-get? patient-records { patient: patient }))
                { ehr-hash: "EMERGENCY_REVOKED" }
            )
        )
        (ok true)
    )
)

(define-read-only (get-active-permissions (patient principal))
    (let
        (
            (current-block stacks-block-height)
        )
        (fold count-active-permissions
            (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
            { patient: patient, current-block: current-block, count: u0 }
        )
    )
)

(define-private (count-active-permissions (token-id uint) (data { patient: principal, current-block: uint, count: uint }))
    (match (map-get? access-permissions { token-id: token-id })
        permission-data
        (if (and
                (is-eq (get patient permission-data) (get patient data))
                (not (get revoked permission-data))
                (> (get expires-at permission-data) (get current-block data))
            )
            (merge data { count: (+ (get count data) u1) })
            data
        )
        data
    )
)

(define-private (update-patient-analytics-on-grant (patient principal) (hospital principal) (current-block uint))
    (let
        (
            (existing-analytics (map-get? patient-analytics { patient: patient }))
        )
        (map-set patient-analytics
            { patient: patient }
            (match existing-analytics
                analytics (merge analytics { 
                    unique-hospitals: (if (is-hospital-new-for-patient patient hospital)
                        (+ (get unique-hospitals analytics) u1)
                        (get unique-hospitals analytics))
                })
                { total-access-count: u0, unique-hospitals: u1, first-grant: current-block, last-access: u0 }
            )
        )
    )
)

(define-private (update-hospital-analytics-on-grant (hospital principal) (patient principal) (permission-level (string-ascii 10)))
    (let
        (
            (existing-analytics (map-get? hospital-analytics { hospital: hospital }))
            (permission-score (get-permission-level-score permission-level))
        )
        (map-set hospital-analytics
            { hospital: hospital }
            (match existing-analytics
                analytics (merge analytics { 
                    unique-patients: (if (is-patient-new-for-hospital hospital patient)
                        (+ (get unique-patients analytics) u1)
                        (get unique-patients analytics)),
                    avg-permission-level: (/ (+ (* (get avg-permission-level analytics) (get unique-patients analytics)) permission-score) (+ (get unique-patients analytics) u1))
                })
                { total-accesses: u0, unique-patients: u1, avg-permission-level: permission-score, compliance-score: u100 }
            )
        )
    )
)

(define-private (update-time-analytics-on-grant (current-block uint) (entity principal))
    (let
        (
            (time-period (/ current-block u144))
            (existing-analytics (map-get? time-based-analytics { time-period: time-period, entity: entity }))
        )
        (map-set time-based-analytics
            { time-period: time-period, entity: entity }
            (match existing-analytics
                analytics (merge analytics { grant-count: (+ (get grant-count analytics) u1) })
                { access-count: u0, grant-count: u1, revoke-count: u0 }
            )
        )
    )
)

(define-private (update-patient-analytics-on-access (patient principal) (current-block uint))
    (let
        (
            (existing-analytics (map-get? patient-analytics { patient: patient }))
        )
        (map-set patient-analytics
            { patient: patient }
            (match existing-analytics
                analytics (merge analytics { 
                    total-access-count: (+ (get total-access-count analytics) u1),
                    last-access: current-block
                })
                { total-access-count: u1, unique-hospitals: u0, first-grant: u0, last-access: current-block }
            )
        )
    )
)

(define-private (update-hospital-analytics-on-access (hospital principal))
    (let
        (
            (existing-analytics (map-get? hospital-analytics { hospital: hospital }))
        )
        (map-set hospital-analytics
            { hospital: hospital }
            (match existing-analytics
                analytics (merge analytics { total-accesses: (+ (get total-accesses analytics) u1) })
                { total-accesses: u1, unique-patients: u0, avg-permission-level: u0, compliance-score: u100 }
            )
        )
    )
)

(define-private (update-time-analytics-on-access (current-block uint) (entity principal))
    (let
        (
            (time-period (/ current-block u144))
            (existing-analytics (map-get? time-based-analytics { time-period: time-period, entity: entity }))
        )
        (map-set time-based-analytics
            { time-period: time-period, entity: entity }
            (match existing-analytics
                analytics (merge analytics { access-count: (+ (get access-count analytics) u1) })
                { access-count: u1, grant-count: u0, revoke-count: u0 }
            )
        )
    )
)

(define-private (is-hospital-new-for-patient (patient principal) (hospital principal))
    (is-none (map-get? patient-consent-history { patient: patient, hospital: hospital }))
)

(define-private (is-patient-new-for-hospital (hospital principal) (patient principal))
    (is-none (map-get? patient-consent-history { patient: patient, hospital: hospital }))
)

(define-read-only (get-analytics-summary (entity principal) (time-start uint) (time-end uint))
    (begin
        (asserts! (<= time-start time-end) ERR_INVALID_TIME_RANGE)
        (let
            (
                (patient-data (get-patient-analytics entity))
                (hospital-data (get-hospital-analytics entity))
            )
            (ok {
                patient-data: patient-data,
                hospital-data: hospital-data,
                time-range: { start: time-start, end: time-end }
            })
        )
    )
)
