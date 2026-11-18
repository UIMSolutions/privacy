# GDPR System - UML Architecture & Diagrams

## 📐 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GDPR Data Protection System                       │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐          ┌──────────────────┐          ┌──────────────┐
│   WebView GUI    │          │   CLI Tool       │          │  External    │
│  (BeerCSS)       │          │  (Node.js CLI)   │          │  Systems     │
│                  │          │                  │          │              │
│ • Consent Mgmt   │          │ • Data Export    │          │ • SAP Fiori  │
│ • DSR Requests   │          │ • Compliance     │          │ • ERP        │
│ • Dashboard      │          │ • Batch Process  │          │ • CRM        │
└────────┬─────────┘          └────────┬─────────┘          └──────┬───────┘
         │                             │                           │
         │                             │                           │
         └─────────────────────────────┼───────────────────────────┘
                                       │
                        ┌──────────────▼───────────────┐
                        │   API Gateway / Middleware   │
                        │  • Authentication (OAuth2)   │
                        │  • Authorization (RBAC)      │
                        │  • Rate Limiting             │
                        │  • Encryption/Decryption     │
                        └──────────────┬───────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
        ▼                              ▼                              ▼
┌───────────────────┐    ┌────────────────────────┐    ┌──────────────────┐
│   OData v4        │    │   Business Logic       │    │   Utilities      │
│   Service Layer   │    │   Layer                │    │                  │
│                   │    │                        │    │ • Encryption     │
│ • Data Subject    │    │ • RequestHandler       │    │ • Anonymization  │
│ • Consent         │    │ • ConsentHandler       │    │ • Validation     │
│ • Processing      │    │ • AuditHandler         │    │ • Formatting     │
│ • Requests        │    │ • ComplianceChecker    │    │                  │
└──────┬────────────┘    └────────┬───────────────┘    └────────┬─────────┘
       │                          │                              │
       └──────────────────────────┼──────────────────────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │   Data Access Layer (DAL)  │
                    │  • ORM (TypeORM)           │
                    │  • Query Builder           │
                    │  • Transaction Manager     │
                    └─────────────┬───────────────┘
                                  │
        ┌─────────────────────────┼──────────────────────┐
        │                         │                      │
        ▼                         ▼                      ▼
┌──────────────────┐   ┌────────────────────┐  ┌──────────────────┐
│  Primary DB      │   │   Audit Log DB     │  │  Cache Layer     │
│  (PostgreSQL)    │   │  (PostgreSQL)      │  │  (Redis)         │
│                  │   │                    │  │                  │
│ • Data Subjects  │   │ • Access Logs      │  │ • Query Cache    │
│ • Consent        │   │ • Modifications    │  │ • Session Store  │
│ • Requests       │   │ • Deletions        │  │                  │
│ • Processing     │   │ • Approvals        │  │                  │
│   Activities     │   │                    │  │                  │
└──────────────────┘   └────────────────────┘  └──────────────────┘
```

## 🔄 Class Diagram - Core Entities

```
┌──────────────────────────┐
│    DataSubject           │
├──────────────────────────┤
│ - id: UUID               │
│ - email: string          │
│ - firstName: string      │
│ - lastName: string       │
│ - phone?: string         │
│ - createdAt: Date        │
│ - updatedAt: Date        │
│ - deletedAt?: Date       │
├──────────────────────────┤
│ + getConsents()          │
│ + getRequests()          │
│ + getProcessingData()    │
│ + requestErasure()       │
│ + exportData()           │
└──────────────────────────┘
         │
         │ 1..* 
         │
         ▼
┌──────────────────────────┐
│  ConsentRecord           │
├──────────────────────────┤
│ - id: UUID               │
│ - subjectId: UUID        │
│ - type: ConsentType      │
│ - status: ConsentStatus  │
│ - version: number        │
│ - grantedAt: Date        │
│ - withdrawnAt?: Date     │
│ - ipAddress: string      │
│ - userAgent: string      │
│ - expiresAt?: Date       │
├──────────────────────────┤
│ + withdraw()             │
│ + renew()                │
│ + validate()             │
└──────────────────────────┘

         ┌────────────────────────────┐
         │   DataRequest              │
         ├────────────────────────────┤
         │ - id: UUID                 │
         │ - subjectId: UUID          │
         │ - type: RequestType        │
         │   (Access, Erasure, etc)   │
         │ - status: RequestStatus    │
         │ - priority: Priority       │
         │ - submittedAt: Date        │
         │ - dueDate: Date            │
         │ - completedAt?: Date       │
         │ - reason?: string          │
         │ - attachments?: File[]     │
         ├────────────────────────────┤
         │ + validateRequest()        │
         │ + processRequest()         │
         │ + generateResponse()       │
         │ + trackProgress()          │
         └────────────────────────────┘

┌────────────────────────────────┐
│  ProcessingActivity            │
├────────────────────────────────┤
│ - id: UUID                     │
│ - name: string                 │
│ - description: string          │
│ - lawfulBasis: LawfulBasis     │
│ - dataCategories: string[]     │
│ - purposes: string[]           │
│ - recipients: string[]         │
│ - retentionPeriod: Duration    │
│ - riskLevel: RiskLevel         │
│ - dpia?: DPIAReport            │
│ - lastReviewedAt: Date         │
├────────────────────────────────┤
│ + assessRisk()                 │
│ + requiresDPIA(): boolean      │
│ + getRetentionSchedule()       │
│ + updateCompliance()           │
└────────────────────────────────┘

         │
         │ 1..*
         │
         ▼
┌────────────────────────────────┐
│  Processor                      │
├────────────────────────────────┤
│ - id: UUID                     │
│ - name: string                 │
│ - type: ProcessorType          │
│ - location: string             │
│ - contactEmail: string         │
│ - dpa?: DataProcessingAgreement│
│ - certifications: string[]     │
│ - lastAuditDate?: Date         │
├────────────────────────────────┤
│ + validateDPA()                │
│ + scheduleAudit()              │
│ + getCertifications()          │
└────────────────────────────────┘
```

## 🔀 Sequence Diagram - Data Access Request

```
Data Subject          WebView              API              Service         Database
    │                  │                   │                   │              │
    │─ Initiates ─────▶│                   │                   │              │
    │  DSR Request     │                   │                   │              │
    │                  │                   │                   │              │
    │                  │─ POST /requests ─▶│                   │              │
    │                  │  (encrypted)      │                   │              │
    │                  │                   │                   │              │
    │                  │                   │─ Authenticate ───▶│              │
    │                  │                   │◀─── Token ───────│              │
    │                  │                   │                   │              │
    │                  │                   │─ Validate ───────▶│              │
    │                  │                   │◀─ Valid ─────────│              │
    │                  │                   │                   │              │
    │                  │                   │─ Create Request ─▶│              │
    │                  │                   │                   │─ Save ──────▶│
    │                  │                   │                   │◀─ ID ───────│
    │                  │                   │◀─ ID ─────────────│              │
    │                  │◀─ 201 Created ────│                   │              │
    │                  │  (request ID)     │                   │              │
    │                  │                   │                   │              │
    │◀─ Confirm ───────│                   │                   │              │
    │  (via Email)     │                   │                   │              │
    │                  │                   │                   │              │
    │                  │                   │─ Query Data ─────▶│              │
    │                  │                   │                   │─ Retrieve ─▶│
    │                  │                   │                   │◀─ Records ──│
    │                  │                   │◀─ Records ────────│              │
    │                  │                   │                   │              │
    │                  │                   │─ Encrypt ────────▶│              │
    │                  │                   │◀─ Encrypted ─────│              │
    │                  │                   │                   │              │
    │                  │◀─ GET /file ──────│                   │              │
    │                  │  (download ready) │                   │              │
    │                  │                   │                   │              │
    │◀─ Download ──────│                   │                   │              │
    │  (Encrypted)     │                   │                   │              │
    │                  │                   │                   │              │
    └────────────────────────────────────────────────────────────────────────
```

## 🔄 State Diagram - Request Lifecycle

```
                    ┌─────────────────┐
                    │ DRAFT           │
                    │ (Initial)       │
                    └────────┬────────┘
                             │
                             │ submit()
                             ▼
                    ┌─────────────────┐
                    │ SUBMITTED       │
                    │ (Received)      │
                    └────────┬────────┘
                             │
                             │ validate()
                             ▼
                    ┌─────────────────┐
        ┌──────────▶│ PENDING_REVIEW  │◀──────────┐
        │           │ (Awaiting Admin)│           │
        │           └────────┬────────┘           │
        │                    │                    │
        │ reject()           │ approve()      hold()
        │                    ▼                    │
        │           ┌─────────────────┐          │
        │           │ IN_PROGRESS     │          │
        │           │ (Processing)    │          │
        │           └────────┬────────┘          │
        │                    │                   │
        │ error()            │ complete()   HELD
        │                    ▼                   │
        │           ┌─────────────────┐          │
        │           │ COMPLETED       │          │
        │           │ (Fulfilled)     │          │
        │           └────────┬────────┘          │
        │                    │                   │
        │                    │ send()            │
        │                    ▼                   │
        │           ┌─────────────────┐          │
        │           │ DELIVERED       │          │
        │           │ (Sent to Subject)          │
        │           └────────┬────────┘          │
        │                    │                   │
        │                    └───────────────────┘
        │
        └─────────────────────────────────────────
                    REJECTED
                 (Denied/Failed)
```

## 📊 Data Flow Diagram - Consent Management

```
┌─────────────────┐
│  User Action    │  (Grant/Revoke/Update)
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Consent Form (WebView)             │
│  • Category Selection               │
│  • Preference Management            │
│  • Clear Explanation of Purpose     │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Validation Layer                   │
│  ✓ Required fields present          │
│  ✓ User identity verified           │
│  ✓ Age verification (if needed)     │
│  ✓ Double opt-in (if applicable)    │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Encryption Service                 │
│  • Encrypt consent data             │
│  • Sign timestamp                   │
│  • Generate proof                   │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Consent Repository                 │
│  • Store in Primary DB              │
│  • Create Audit Log Entry           │
│  • Update Cache                     │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Notification Service               │
│  • Confirm to User (Email)          │
│  • Notify Processors                │
│  • Archive Proof                    │
└─────────────────────────────────────┘
```

## 🔐 Security Architecture

```
┌──────────────────────────────────────────────┐
│          Encryption Layer                     │
├──────────────────────────────────────────────┤
│ • TLS 1.3+ for Transport                     │
│ • AES-256 for Data at Rest                   │
│ • HMAC for Data Integrity                    │
└──────────────────────────────────────────────┘
              ▲
              │
┌──────────────────────────────────────────────┐
│      Authentication & Authorization           │
├──────────────────────────────────────────────┤
│ • OAuth 2.0 / OpenID Connect                 │
│ • JWT Bearer Tokens                          │
│ • Role-Based Access Control (RBAC)           │
│ • Attribute-Based Access Control (ABAC)      │
└──────────────────────────────────────────────┘
              ▲
              │
┌──────────────────────────────────────────────┐
│        Audit & Compliance Layer               │
├──────────────────────────────────────────────┤
│ • Immutable Audit Logs                       │
│ • Operation Tracking                         │
│ • Change Logging                             │
│ • Compliance Reports                         │
└──────────────────────────────────────────────┘
```

## 🎯 Component Interaction Matrix

| Component | OData | GUI | CLI | Audit | Cache |
|-----------|-------|-----|-----|-------|-------|
| DataSubject | ✓ | ✓ | ✓ | ✓ | ✓ |
| ConsentRecord | ✓ | ✓ | ✓ | ✓ | ✓ |
| DataRequest | ✓ | ✓ | ✓ | ✓ | - |
| ProcessingActivity | ✓ | - | ✓ | ✓ | ✓ |
| Processor | ✓ | - | ✓ | ✓ | ✓ |
| AuditLog | - | - | ✓ | ✓ | - |

## 📈 Deployment Architecture

```
┌─────────────────────────────────────────────────┐
│         Load Balancer (HTTPS)                   │
└────────────────┬────────────────────────────────┘
                 │
     ┌───────────┼───────────┐
     │           │           │
     ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Instance│ │ Instance│ │ Instance│
│   1     │ │   2     │ │   3     │
└────┬────┘ └────┬────┘ └────┬────┘
     │           │           │
     └───────────┼───────────┘
                 │
     ┌───────────┼───────────┐
     │           │           │
     ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ OData    │ │ GUI      │ │ CLI      │
│ Service  │ │ Service  │ │ Worker   │
└────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │
     └────────────┼────────────┘
                  │
              ┌───┴────┬──────────┐
              │        │          │
              ▼        ▼          ▼
           ┌────┐ ┌────────┐ ┌────────┐
           │ DB │ │ Cache  │ │Audit   │
           │    │ │(Redis) │ │Log DB  │
           └────┘ └────────┘ └────────┘
```

---

**Last Updated**: November 2026  
**Version**: 1.0.0
