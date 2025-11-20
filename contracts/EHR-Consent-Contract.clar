

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
(define-constant ERR_TEMPLATE_NOT_FOUND (err u112))
(define-constant ERR_TEMPLATE_ALREADY_EXISTS (err u113))
(define-constant ERR_AUDIT_ACCESS_DENIED (err u114))
(define-constant ERR_INVALID_AUDIT_LEVEL (err u115))
(define-constant ERR_AUDIT_NOT_FOUND (err u116))
(define-constant ERR_DELEGATE_NOT_FOUND (err u117))
(define-constant ERR_DELEGATE_ALREADY_EXISTS (err u118))
(define-constant ERR_CANNOT_DELEGATE_TO_SELF (err u119))
(define-constant ERR_DELEGATE_INACTIVE (err u120))

(define-data-var last-token-id uint u0)
(define-data-var last-delegation-id uint u0)
(define-data-var oracle-address (optional principal) none)
(define-data-var last-template-id uint u0)
(define-data-var last-audit-id uint u0)

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

(define-map consent-templates
    { template-id: uint }
    {
        owner: principal,
        name: (string-ascii 50),
        permission-level: (string-ascii 10),
        duration: uint,
        created-at: uint,
        active: bool
    }
)

(define-map patient-templates
    { patient: principal, template-name: (string-ascii 50) }
    { template-id: uint }
)

;; Comprehensive Audit Trail System
(define-map audit-trail
    { audit-id: uint }
    {
        event-type: (string-ascii 20),
        patient: principal,
        actor: principal,
        hospital: (optional principal),
        token-id: (optional uint),
        timestamp: uint,
        block-height: uint,
        details: (string-ascii 100),
        severity-level: (string-ascii 10),
        compliance-flag: bool
    }
)

(define-map patient-audit-log
    { patient: principal }
    { total-events: uint, last-audit-id: uint, high-risk-events: uint }
)

(define-map hospital-audit-log
    { hospital: principal }
    { total-events: uint, compliance-score: uint, violations: uint }
)

(define-map audit-search-index
    { event-type: (string-ascii 20), entity: principal }
    { event-count: uint, last-event-id: uint }
)

(define-map patient-delegates
    { delegation-id: uint }
    {
        patient: principal,
        delegate: principal,
        permission-scope: (string-ascii 20),
        created-at: uint,
        expires-at: uint,
        active: bool,
        usage-count: uint
    }
)

(define-map active-delegations
    { patient: principal, delegate: principal }
    { delegation-id: uint }
)

(define-map delegate-registry
    { delegate: principal }
    { total-delegations: uint, active-count: uint, last-action: uint }
)

(define-read-only (get-last-token-id)
    (var-get last-token-id)
)

(define-read-only (get-last-template-id)
    (var-get last-template-id)
)

(define-read-only (get-last-audit-id)
    (var-get last-audit-id)
)

(define-read-only (get-last-delegation-id)
    (var-get last-delegation-id)
)

(define-read-only (get-delegation (delegation-id uint))
    (map-get? patient-delegates { delegation-id: delegation-id })
)

(define-read-only (get-active-delegation (patient principal) (delegate principal))
    (match (map-get? active-delegations { patient: patient, delegate: delegate })
        delegation-ref (map-get? patient-delegates { delegation-id: (get delegation-id delegation-ref) })
        none
    )
)

(define-read-only (get-delegate-info (delegate principal))
    (map-get? delegate-registry { delegate: delegate })
)

(define-read-only (is-valid-delegate (patient principal) (delegate principal))
    (match (get-active-delegation patient delegate)
        delegation-data
        (and
            (get active delegation-data)
            (> (get expires-at delegation-data) stacks-block-height)
        )
        false
    )
)

(define-read-only (get-audit-record (audit-id uint))
    (map-get? audit-trail { audit-id: audit-id })
)

(define-read-only (get-patient-audit-summary (patient principal))
    (map-get? patient-audit-log { patient: patient })
)

(define-read-only (get-hospital-audit-summary (hospital principal))
    (map-get? hospital-audit-log { hospital: hospital })
)

(define-read-only (get-audit-events-by-type (event-type (string-ascii 20)) (entity principal))
    (map-get? audit-search-index { event-type: event-type, entity: entity })
)

(define-read-only (get-consent-template (template-id uint))
    (map-get? consent-templates { template-id: template-id })
)

(define-read-only (get-patient-template-by-name (patient principal) (template-name (string-ascii 50)))
    (match (map-get? patient-templates { patient: patient, template-name: template-name })
        template-ref (map-get? consent-templates { template-id: (get template-id template-ref) })
        none
    )
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

(define-read-only (is-valid-severity-level (severity (string-ascii 10)))
    (or (is-eq severity "info")
        (or (is-eq severity "warning")
            (or (is-eq severity "critical")
                (is-eq severity "emergency"))))
)

(define-read-only (is-valid-event-type (event-type (string-ascii 20)))
    (or (is-eq event-type "access_granted")
        (or (is-eq event-type "access_revoked")
            (or (is-eq event-type "data_accessed")
                (or (is-eq event-type "permission_expired")
                    (or (is-eq event-type "emergency_revoke")
                        (or (is-eq event-type "compliance_check")
                            (is-eq event-type "security_violation")))))))
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

;; Comprehensive Audit Trail Functions
(define-public (create-audit-record 
    (event-type (string-ascii 20)) 
    (patient principal) 
    (hospital (optional principal))
    (token-id (optional uint))
    (details (string-ascii 100))
    (severity-level (string-ascii 10)))
    (let
        (
            (audit-id (+ (var-get last-audit-id) u1))
            (current-block stacks-block-height)
            (compliance-flag (not (is-eq severity-level "critical")))
        )
        (asserts! (is-valid-event-type event-type) ERR_INVALID_AUDIT_LEVEL)
        (asserts! (is-valid-severity-level severity-level) ERR_INVALID_AUDIT_LEVEL)
        (asserts! (or (is-eq tx-sender patient) 
                     (is-eq tx-sender CONTRACT_OWNER)
                     (is-some (map-get? hospital-registry { hospital: tx-sender }))) ERR_AUDIT_ACCESS_DENIED)
        
        (map-set audit-trail
            { audit-id: audit-id }
            {
                event-type: event-type,
                patient: patient,
                actor: tx-sender,
                hospital: hospital,
                token-id: token-id,
                timestamp: current-block,
                block-height: current-block,
                details: details,
                severity-level: severity-level,
                compliance-flag: compliance-flag
            }
        )
        
        (update-patient-audit-log patient audit-id severity-level)
        (match hospital
            hosp (update-hospital-audit-log hosp severity-level)
            true
        )
        (update-audit-search-index event-type patient audit-id)
        
        (var-set last-audit-id audit-id)
        (ok audit-id)
    )
)

(define-public (query-audit-trail
    (patient principal)
    (event-type (optional (string-ascii 20)))
    (severity-filter (optional (string-ascii 10)))
    (limit uint))
    (let
        (
            (can-access (or (is-eq tx-sender patient)
                          (is-eq tx-sender CONTRACT_OWNER)
                          (is-some (get-patient-consent-for-audit tx-sender patient))))
        )
        (asserts! can-access ERR_AUDIT_ACCESS_DENIED)
        (asserts! (> limit u0) ERR_INVALID_DURATION)
        (asserts! (<= limit u50) ERR_INVALID_DURATION)
        
        (ok (fold search-audit-records
            (generate-audit-id-list limit)
            { 
                patient: patient, 
                event-filter: event-type, 
                severity-filter: severity-filter,
                results: (list),
                count: u0
            })
        )
    )
)

(define-public (generate-compliance-report 
    (entity principal)
    (report-type (string-ascii 10))
    (time-start uint)
    (time-end uint))
    (let
        (
            (can-generate (or (is-eq tx-sender entity)
                            (is-eq tx-sender CONTRACT_OWNER)
                            (is-some (map-get? hospital-registry { hospital: tx-sender }))))
        )
        (asserts! can-generate ERR_AUDIT_ACCESS_DENIED)
        (asserts! (<= time-start time-end) ERR_INVALID_TIME_RANGE)
        (asserts! (or (is-eq report-type "patient") (is-eq report-type "hospital")) ERR_INVALID_AUDIT_LEVEL)
        
        (let
            (
                (patient-summary (if (is-eq report-type "patient")
                    (get-patient-audit-summary entity)
                    none))
                (hospital-summary (if (is-eq report-type "hospital")
                    (get-hospital-audit-summary entity)
                    none))
                (compliance-score (calculate-compliance-score entity report-type))
            )
            (ok {
                entity: entity,
                report-type: report-type,
                time-range: { start: time-start, end: time-end },
                patient-summary: patient-summary,
                hospital-summary: hospital-summary,
                compliance-score: compliance-score,
                generated-at: stacks-block-height,
                generated-by: tx-sender
            })
        )
    )
)

(define-public (flag-security-violation
    (violating-entity principal)
    (violation-type (string-ascii 20))
    (details (string-ascii 100)))
    (begin
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                     (is-some (map-get? hospital-registry { hospital: tx-sender }))) ERR_AUDIT_ACCESS_DENIED)
        
        (try! (create-audit-record
            "security_violation"
            violating-entity
            (some tx-sender)
            none
            details
            "critical"
        ))
        
        (match (map-get? hospital-audit-log { hospital: violating-entity })
            existing-log (map-set hospital-audit-log
                { hospital: violating-entity }
                (merge existing-log { violations: (+ (get violations existing-log) u1) })
            )
            (map-set hospital-audit-log
                { hospital: violating-entity }
                { total-events: u1, compliance-score: u0, violations: u1 }
            )
        )
        
        (ok true)
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

(define-public (create-consent-template (name (string-ascii 50)) (permission-level (string-ascii 10)) (duration uint))
    (let
        (
            (template-id (+ (var-get last-template-id) u1))
            (current-block stacks-block-height)
        )
        (asserts! (is-none (map-get? patient-templates { patient: tx-sender, template-name: name })) ERR_TEMPLATE_ALREADY_EXISTS)
        (asserts! (is-valid-permission permission-level) ERR_INVALID_PERMISSION)
        (asserts! (> duration u0) ERR_INVALID_DURATION)
        
        (map-set consent-templates
            { template-id: template-id }
            {
                owner: tx-sender,
                name: name,
                permission-level: permission-level,
                duration: duration,
                created-at: current-block,
                active: true
            }
        )
        
        (map-set patient-templates
            { patient: tx-sender, template-name: name }
            { template-id: template-id }
        )
        
        (var-set last-template-id template-id)
        (ok template-id)
    )
)

(define-public (update-consent-template (template-id uint) (permission-level (string-ascii 10)) (duration uint))
    (let
        (
            (template-data (unwrap! (map-get? consent-templates { template-id: template-id }) ERR_TEMPLATE_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get owner template-data)) ERR_UNAUTHORIZED)
        (asserts! (get active template-data) ERR_TEMPLATE_NOT_FOUND)
        (asserts! (is-valid-permission permission-level) ERR_INVALID_PERMISSION)
        (asserts! (> duration u0) ERR_INVALID_DURATION)
        
        (map-set consent-templates
            { template-id: template-id }
            (merge template-data {
                permission-level: permission-level,
                duration: duration
            })
        )
        (ok true)
    )
)

(define-public (deactivate-consent-template (template-id uint))
    (let
        (
            (template-data (unwrap! (map-get? consent-templates { template-id: template-id }) ERR_TEMPLATE_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get owner template-data)) ERR_UNAUTHORIZED)
        (map-set consent-templates
            { template-id: template-id }
            (merge template-data { active: false })
        )
        (ok true)
    )
)

(define-public (grant-access-with-template (to principal) (hospital principal) (template-id uint))
    (let
        (
            (template-data (unwrap! (map-get? consent-templates { template-id: template-id }) ERR_TEMPLATE_NOT_FOUND))
            (token-id (+ (var-get last-token-id) u1))
            (patient-record (unwrap! (map-get? patient-records { patient: tx-sender }) ERR_NOT_TOKEN_OWNER))
            (hospital-data (unwrap! (map-get? hospital-registry { hospital: hospital }) ERR_HOSPITAL_NOT_REGISTERED))
            (current-block stacks-block-height)
            (expires-at (+ current-block (get duration template-data)))
        )
        (asserts! (is-eq tx-sender (get owner template-data)) ERR_UNAUTHORIZED)
        (asserts! (get active template-data) ERR_TEMPLATE_NOT_FOUND)
        (asserts! (get verified hospital-data) ERR_HOSPITAL_NOT_REGISTERED)
        (asserts! (is-valid-permission (get permission-level template-data)) ERR_INVALID_PERMISSION)
        
        (try! (nft-mint? ehr-access-key token-id to))
        
        (map-set access-permissions
            { token-id: token-id }
            {
                patient: tx-sender,
                granted-to: to,
                permission-level: (get permission-level template-data),
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
        (update-hospital-analytics-on-grant hospital tx-sender (get permission-level template-data))
        (update-time-analytics-on-grant current-block tx-sender)
        (try! (create-audit-record 
            "access_granted" 
            tx-sender 
            (some hospital) 
            (some token-id) 
            "EHR access granted via template" 
            "info"))
        
        (ok token-id)
    )
)

(define-public (create-delegation (delegate principal) (permission-scope (string-ascii 20)) (duration uint))
    (let
        (
            (delegation-id (+ (var-get last-delegation-id) u1))
            (current-block stacks-block-height)
            (expires-at (+ current-block duration))
        )
        (asserts! (is-some (map-get? patient-records { patient: tx-sender })) ERR_NOT_TOKEN_OWNER)
        (asserts! (not (is-eq tx-sender delegate)) ERR_CANNOT_DELEGATE_TO_SELF)
        (asserts! (is-none (map-get? active-delegations { patient: tx-sender, delegate: delegate })) ERR_DELEGATE_ALREADY_EXISTS)
        (asserts! (> duration u0) ERR_INVALID_DURATION)
        (asserts! (or (is-eq permission-scope "grant") 
                     (or (is-eq permission-scope "revoke") 
                         (is-eq permission-scope "full"))) ERR_INVALID_PERMISSION)
        
        (map-set patient-delegates
            { delegation-id: delegation-id }
            {
                patient: tx-sender,
                delegate: delegate,
                permission-scope: permission-scope,
                created-at: current-block,
                expires-at: expires-at,
                active: true,
                usage-count: u0
            }
        )
        
        (map-set active-delegations
            { patient: tx-sender, delegate: delegate }
            { delegation-id: delegation-id }
        )
        
        (map-set delegate-registry
            { delegate: delegate }
            (match (map-get? delegate-registry { delegate: delegate })
                registry (merge registry { 
                    total-delegations: (+ (get total-delegations registry) u1),
                    active-count: (+ (get active-count registry) u1),
                    last-action: current-block
                })
                { total-delegations: u1, active-count: u1, last-action: current-block }
            )
        )
        
        (var-set last-delegation-id delegation-id)
        (try! (create-audit-record 
            "access_granted" 
            tx-sender 
            none 
            none 
            "Delegation created for healthcare proxy" 
            "info"))
        (ok delegation-id)
    )
)

(define-public (revoke-delegation (delegation-id uint))
    (let
        (
            (delegation-data (unwrap! (map-get? patient-delegates { delegation-id: delegation-id }) ERR_DELEGATE_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get patient delegation-data)) ERR_UNAUTHORIZED)
        (asserts! (get active delegation-data) ERR_DELEGATE_INACTIVE)
        
        (map-set patient-delegates
            { delegation-id: delegation-id }
            (merge delegation-data { active: false })
        )
        
        (map-delete active-delegations { patient: (get patient delegation-data), delegate: (get delegate delegation-data) })
        
        (match (map-get? delegate-registry { delegate: (get delegate delegation-data) })
            registry (map-set delegate-registry
                { delegate: (get delegate delegation-data) }
                (merge registry { active-count: (if (> (get active-count registry) u0) (- (get active-count registry) u1) u0) })
            )
            false
        )
        
        (try! (create-audit-record 
            "access_revoked" 
            (get patient delegation-data) 
            none 
            none 
            "Delegation revoked" 
            "warning"))
        (ok true)
    )
)

(define-public (delegate-grant-access (patient principal) (to principal) (hospital principal) (permission-level (string-ascii 10)) (duration uint))
    (let
        (
            (delegation-data (unwrap! (get-active-delegation patient tx-sender) ERR_DELEGATE_NOT_FOUND))
            (token-id (+ (var-get last-token-id) u1))
            (patient-record (unwrap! (map-get? patient-records { patient: patient }) ERR_NOT_TOKEN_OWNER))
            (hospital-data (unwrap! (map-get? hospital-registry { hospital: hospital }) ERR_HOSPITAL_NOT_REGISTERED))
            (current-block stacks-block-height)
            (expires-at (+ current-block duration))
        )
        (asserts! (get active delegation-data) ERR_DELEGATE_INACTIVE)
        (asserts! (> (get expires-at delegation-data) current-block) ERR_TOKEN_EXPIRED)
        (asserts! (or (is-eq (get permission-scope delegation-data) "grant")
                     (is-eq (get permission-scope delegation-data) "full")) ERR_PERMISSION_DENIED)
        (asserts! (get verified hospital-data) ERR_HOSPITAL_NOT_REGISTERED)
        (asserts! (is-valid-permission permission-level) ERR_INVALID_PERMISSION)
        (asserts! (> duration u0) ERR_INVALID_DURATION)
        
        (try! (nft-mint? ehr-access-key token-id to))
        
        (map-set access-permissions
            { token-id: token-id }
            {
                patient: patient,
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
            { patient: patient, hospital: hospital }
            (match (map-get? patient-consent-history { patient: patient, hospital: hospital })
                history (merge history { total-grants: (+ (get total-grants history) u1), last-granted: current-block })
                { total-grants: u1, last-granted: current-block }
            )
        )
        
        (update-patient-analytics-on-grant patient hospital current-block)
        (update-hospital-analytics-on-grant hospital patient permission-level)
        (update-time-analytics-on-grant current-block patient)
        (increment-delegation-usage (get delegation-id (unwrap-panic (map-get? active-delegations { patient: patient, delegate: tx-sender }))))
        (try! (create-audit-record 
            "access_granted" 
            patient 
            (some hospital) 
            (some token-id) 
            "EHR access granted by delegate" 
            "info"))
        
        (ok token-id)
    )
)

(define-public (delegate-revoke-access (patient principal) (token-id uint))
    (let
        (
            (delegation-data (unwrap! (get-active-delegation patient tx-sender) ERR_DELEGATE_NOT_FOUND))
            (permission-data (unwrap! (map-get? access-permissions { token-id: token-id }) ERR_TOKEN_NOT_FOUND))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq patient (get patient permission-data)) ERR_UNAUTHORIZED)
        (asserts! (get active delegation-data) ERR_DELEGATE_INACTIVE)
        (asserts! (> (get expires-at delegation-data) current-block) ERR_TOKEN_EXPIRED)
        (asserts! (or (is-eq (get permission-scope delegation-data) "revoke")
                     (is-eq (get permission-scope delegation-data) "full")) ERR_PERMISSION_DENIED)
        
        (map-set access-permissions
            { token-id: token-id }
            (merge permission-data { revoked: true })
        )
        
        (increment-delegation-usage (get delegation-id (unwrap-panic (map-get? active-delegations { patient: patient, delegate: tx-sender }))))
        (try! (create-audit-record 
            "access_revoked" 
            patient 
            (some (get hospital permission-data)) 
            (some token-id) 
            "EHR access revoked by delegate" 
            "warning"))
        (ok true)
    )
)

(define-private (increment-delegation-usage (delegation-id uint))
    (match (map-get? patient-delegates { delegation-id: delegation-id })
        delegation (begin
            (map-set patient-delegates
                { delegation-id: delegation-id }
                (merge delegation { usage-count: (+ (get usage-count delegation) u1) })
            )
            true
        )
        false
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
        (try! (create-audit-record 
            "access_granted" 
            tx-sender 
            (some hospital) 
            (some token-id) 
            "EHR access granted directly" 
            "info"))
        
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
        (try! (create-audit-record 
            "access_revoked" 
            (get patient permission-data) 
            (some (get hospital permission-data)) 
            (some token-id) 
            "Patient revoked EHR access" 
            "warning"))
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
        (try! (create-audit-record 
            "data_accessed" 
            (get patient permission-data) 
            (some (get hospital permission-data)) 
            (some token-id) 
            "Healthcare provider accessed EHR data" 
            "info"))
        
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
        (try! (create-audit-record 
            "emergency_revoke" 
            patient 
            none 
            none 
            "Emergency revocation of all access" 
            "emergency"))
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

;; Audit Trail Helper Functions
(define-private (update-patient-audit-log (patient principal) (audit-id uint) (severity (string-ascii 10)))
    (let
        (
            (existing-log (map-get? patient-audit-log { patient: patient }))
            (is-high-risk (or (is-eq severity "critical") (is-eq severity "emergency")))
        )
        (map-set patient-audit-log
            { patient: patient }
            (match existing-log
                log (merge log {
                    total-events: (+ (get total-events log) u1),
                    last-audit-id: audit-id,
                    high-risk-events: (if is-high-risk 
                        (+ (get high-risk-events log) u1) 
                        (get high-risk-events log))
                })
                { total-events: u1, last-audit-id: audit-id, high-risk-events: (if is-high-risk u1 u0) }
            )
        )
    )
)

(define-private (update-hospital-audit-log (hospital principal) (severity (string-ascii 10)))
    (let
        (
            (existing-log (map-get? hospital-audit-log { hospital: hospital }))
            (is-violation (or (is-eq severity "critical") (is-eq severity "emergency")))
            (score-penalty (if is-violation u10 u0))
        )
        (map-set hospital-audit-log
            { hospital: hospital }
            (match existing-log
                log (merge log {
                    total-events: (+ (get total-events log) u1),
                    compliance-score: (if (> (get compliance-score log) score-penalty)
                        (- (get compliance-score log) score-penalty)
                        u0),
                    violations: (if is-violation 
                        (+ (get violations log) u1) 
                        (get violations log))
                })
                { total-events: u1, compliance-score: (if is-violation u90 u100), violations: (if is-violation u1 u0) }
            )
        )
    )
)

(define-private (update-audit-search-index (event-type (string-ascii 20)) (entity principal) (audit-id uint))
    (let
        (
            (existing-index (map-get? audit-search-index { event-type: event-type, entity: entity }))
        )
        (map-set audit-search-index
            { event-type: event-type, entity: entity }
            (match existing-index
                index (merge index {
                    event-count: (+ (get event-count index) u1),
                    last-event-id: audit-id
                })
                { event-count: u1, last-event-id: audit-id }
            )
        )
    )
)

(define-private (get-patient-consent-for-audit (requester principal) (patient principal))
    (get found (fold check-audit-permissions
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
        { patient: patient, requester: requester, found: none }
    ))
)

(define-private (check-audit-permissions (token-id uint) (data { patient: principal, requester: principal, found: (optional bool) }))
    (if (is-some (get found data))
        data
        (match (map-get? access-permissions { token-id: token-id })
            permission
            (if (and
                    (is-eq (get patient permission) (get patient data))
                    (is-eq (get granted-to permission) (get requester data))
                    (not (get revoked permission))
                    (> (get expires-at permission) stacks-block-height)
                    (or (is-eq (get permission-level permission) "admin")
                        (is-eq (get permission-level permission) "modify"))
                )
                (merge data { found: (some true) })
                data
            )
            data
        )
    )
)

(define-private (calculate-compliance-score (entity principal) (report-type (string-ascii 10)))
    (if (is-eq report-type "patient")
        (match (get-patient-audit-summary entity)
            summary (if (> (get high-risk-events summary) u0)
                (- u100 (* (get high-risk-events summary) u5))
                u100)
            u100
        )
        (match (get-hospital-audit-summary entity)
            summary (get compliance-score summary)
            u100
        )
    )
)

(define-private (generate-audit-id-list (limit uint))
    (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
)

(define-private (search-audit-records (audit-id uint) (search-data { patient: principal, event-filter: (optional (string-ascii 20)), severity-filter: (optional (string-ascii 10)), results: (list 50 uint), count: uint }))
    (if (>= (get count search-data) u50)
        search-data
        (match (map-get? audit-trail { audit-id: audit-id })
            record
            (if (and
                    (is-eq (get patient record) (get patient search-data))
                    (match (get event-filter search-data)
                        event-type (is-eq (get event-type record) event-type)
                        true
                    )
                    (match (get severity-filter search-data)
                        severity (is-eq (get severity-level record) severity)
                        true
                    )
                )
                (merge search-data {
                    results: (unwrap-panic (as-max-len? (append (get results search-data) audit-id) u50)),
                    count: (+ (get count search-data) u1)
                })
                search-data
            )
            search-data
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
