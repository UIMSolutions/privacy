# GDPR System - OData v4 API Specification (NAF v4)

## 📋 Overview

The GDPR Data Protection Management System exposes a comprehensive OData v4 service providing standardized REST-based access to all data and functionality. This specification follows OData v4.0 standards and includes CRUD operations, complex queries, and batch processing capabilities.

## 🌐 Service Endpoints

**Base URL**: `https://api.gdpr.company.com/odata/v4/gdpr`

**Service Metadata**: `$metadata` (XML description of the service)

## 📐 Entity Model

### 1. DataSubject Entity

Represents individuals who are the subjects of personal data processing.

**Namespace**: `GDPR.DataSubject`

**URI Pattern**: `/DataSubjects('{id}')`

```
DataSubject
├─ id: UUID (Key)
├─ email: Edm.String (Required, Unique)
├─ firstName: Edm.String (Required)
├─ lastName: Edm.String (Required)
├─ phone: Edm.String
├─ dateOfBirth: Edm.Date
├─ country: Edm.String (ISO 3166-1)
├─ status: Edm.String (Active, Inactive, Deleted)
├─ createdAt: Edm.DateTimeOffset (Server Generated)
├─ updatedAt: Edm.DateTimeOffset (Server Generated)
├─ deletedAt: Edm.DateTimeOffset
└─ Relationships
   ├─ Consents: NavigationProperty → ConsentRecord (1:*)
   ├─ Requests: NavigationProperty → DataRequest (1:*)
   ├─ ProcessingData: NavigationProperty → ProcessingRecord (1:*)
   └─ Communications: NavigationProperty → Communication (1:*)
```

**Operations**:
- `GET /DataSubjects` - List all subjects (with filtering, sorting, paging)
- `GET /DataSubjects('{id}')` - Get specific subject
- `POST /DataSubjects` - Create new subject
- `PATCH /DataSubjects('{id}')` - Update subject
- `DELETE /DataSubjects('{id}')` - Soft delete subject

**Query Examples**:
```
# Get all active data subjects
GET /DataSubjects?$filter=status eq 'Active'

# Get subjects with pagination
GET /DataSubjects?$top=50&$skip=100&$orderby=createdAt desc

# Expand related consents
GET /DataSubjects('{id}')?$expand=Consents

# Select specific properties
GET /DataSubjects?$select=id,email,firstName,lastName
```

### 2. ConsentRecord Entity

Represents granular consent decisions made by data subjects.

**Namespace**: `GDPR.ConsentRecord`

**URI Pattern**: `/ConsentRecords('{id}')`

```
ConsentRecord
├─ id: UUID (Key)
├─ subjectId: UUID (Required, FK → DataSubject)
├─ category: Edm.String (Required)
│  └─ Enum: Marketing, Analytics, Profiling, Thirdparty, Essential
├─ type: Edm.String
│  └─ Enum: Explicit, Implicit, Opt-In, Opt-Out
├─ status: Edm.String (Required)
│  └─ Enum: Granted, Withdrawn, Revoked, Expired
├─ version: Edm.Int32
├─ grantedAt: Edm.DateTimeOffset
├─ withdrawnAt: Edm.DateTimeOffset
├─ expiresAt: Edm.DateTimeOffset
├─ ipAddress: Edm.String
├─ userAgent: Edm.String
├─ consentProof: Edm.String (Signed hash)
├─ processedBy: Edm.String (User/System ID)
└─ Relationships
   └─ Subject: NavigationProperty → DataSubject (0..1)
```

**Operations**:
- `GET /ConsentRecords` - List all consent records
- `GET /ConsentRecords('{id}')` - Get specific consent
- `POST /ConsentRecords` - Grant new consent
- `PATCH /ConsentRecords('{id}')` - Update consent status
- `DELETE /ConsentRecords('{id}')` - Revoke consent (creates withdrawal record)

**Query Examples**:
```
# Get all granted consents for a subject
GET /ConsentRecords?$filter=subjectId eq '{id}' and status eq 'Granted'

# Get expired consents
GET /ConsentRecords?$filter=expiresAt lt now()

# Get consent history (all versions)
GET /ConsentRecords?$filter=subjectId eq '{id}'&$orderby=version desc

# Search by consent category
GET /ConsentRecords?$filter=category eq 'Marketing'&$count=true
```

### 3. DataRequest Entity

Represents formal data subject rights requests (access, erasure, portability, etc.).

**Namespace**: `GDPR.DataRequest`

**URI Pattern**: `/DataRequests('{id}')`

```
DataRequest
├─ id: UUID (Key)
├─ subjectId: UUID (Required, FK → DataSubject)
├─ type: Edm.String (Required)
│  └─ Enum: Access, Erasure, Rectification, Portability, Objection, Restriction
├─ status: Edm.String (Required)
│  └─ Enum: Draft, Submitted, UnderReview, Approved, InProgress, Completed, Rejected
├─ priority: Edm.String
│  └─ Enum: Low, Medium, High, Critical
├─ submittedAt: Edm.DateTimeOffset
├─ dueDate: Edm.DateTimeOffset (Calculated: submittedAt + 30 days)
├─ completedAt: Edm.DateTimeOffset
├─ reason: Edm.String
├─ attachments: Collection(Edm.String) (File URLs)
├─ responseFormat: Edm.String
│  └─ Enum: JSON, CSV, PDF, XML
├─ deliveryMethod: Edm.String
│  └─ Enum: Email, Download, Portal, SecureLink
├─ statusReason: Edm.String (Why rejected/held)
├─ approvedBy: Edm.String (User ID)
├─ completedBy: Edm.String (User ID)
└─ Relationships
   ├─ Subject: NavigationProperty → DataSubject (0..1)
   └─ Attachments: NavigationProperty → Attachment (1:*)
```

**Operations**:
- `GET /DataRequests` - List all requests
- `GET /DataRequests('{id}')` - Get specific request with status
- `POST /DataRequests` - Submit new request
- `PATCH /DataRequests('{id}')` - Update request (status, attachments, etc.)
- `DELETE /DataRequests('{id}')` - Cancel request (if permitted)
- `POST /DataRequests('{id}')/approve` - Approve request (admin only)
- `POST /DataRequests('{id}')/reject` - Reject request (admin only)
- `POST /DataRequests('{id}')/export` - Generate export file
- `GET /DataRequests('{id}')/download` - Download response file

**Query Examples**:
```
# Get all pending erasure requests due in next 7 days
GET /DataRequests?$filter=type eq 'Erasure' and status eq 'Approved' and dueDate le now() add Duration'P7D'

# Get access requests by priority
GET /DataRequests?$filter=type eq 'Access' and priority eq 'High'&$orderby=submittedAt asc

# Get requests needing review
GET /DataRequests?$filter=status eq 'UnderReview'

# Get completed requests (export stats)
GET /DataRequests?$filter=status eq 'Completed' and completedAt ge now() sub Duration'P30D'&$count=true
```

### 4. ProcessingActivity Entity

Represents processing activities and their lawful basis under GDPR.

**Namespace**: `GDPR.ProcessingActivity`

**URI Pattern**: `/ProcessingActivities('{id}')`

```
ProcessingActivity
├─ id: UUID (Key)
├─ name: Edm.String (Required)
├─ description: Edm.String (Required)
├─ department: Edm.String
├─ lawfulBasis: Edm.String (Required)
│  └─ Enum: Consent, Contract, LegalObligation, VitalInterests, PublicTask, LegitimateInterests
├─ dataCategories: Collection(Edm.String)
│  └─ Examples: PersonalIdentifiers, ContactInfo, FinancialData, HealthData, BiometricData
├─ purposes: Collection(Edm.String)
├─ recipients: Collection(Edm.String) (Processor names)
├─ retentionPeriod: Edm.String (ISO 8601 duration)
├─ riskLevel: Edm.String
│  └─ Enum: Low, Medium, High, Critical
├─ requiresDPIA: Edm.Boolean (Calculated)
├─ dpia: Edm.String (DPIA report URL/reference)
├─ dataProtectionOfficer: Edm.String
├─ lastReviewedAt: Edm.DateTimeOffset
├─ nextReviewDueAt: Edm.DateTimeOffset
├─ status: Edm.String
│  └─ Enum: Active, Inactive, Suspended, Archived
└─ Relationships
   ├─ Processors: NavigationProperty → Processor (1:*)
   └─ ComplianceChecks: NavigationProperty → ComplianceCheck (1:*)
```

**Operations**:
- `GET /ProcessingActivities` - List all processing activities
- `GET /ProcessingActivities('{id}')` - Get specific activity with details
- `POST /ProcessingActivities` - Create new processing activity
- `PATCH /ProcessingActivities('{id}')` - Update activity
- `DELETE /ProcessingActivities('{id}')` - Archive activity
- `POST /ProcessingActivities('{id}')/assessRisk` - Trigger risk assessment
- `POST /ProcessingActivities('{id}')/requiresDPIA` - Check if DPIA needed

**Query Examples**:
```
# Get high-risk processing activities
GET /ProcessingActivities?$filter=riskLevel eq 'High' or riskLevel eq 'Critical'

# Get activities requiring DPIA
GET /ProcessingActivities?$filter=requiresDPIA eq true

# Get activities by lawful basis
GET /ProcessingActivities?$filter=lawfulBasis eq 'Consent'

# Get activities needing review
GET /ProcessingActivities?$filter=nextReviewDueAt lt now()
```

### 5. Processor Entity

Represents data processors and sub-processors.

**Namespace**: `GDPR.Processor`

**URI Pattern**: `/Processors('{id}')`

```
Processor
├─ id: UUID (Key)
├─ name: Edm.String (Required, Unique)
├─ type: Edm.String (Required)
│  └─ Enum: Processor, SubProcessor, Joint, DataBroker
├─ category: Edm.String
│  └─ Examples: Cloud, Software, Logistics, Marketing, Analytics
├─ country: Edm.String (ISO 3166-1)
├─ contactEmail: Edm.String
├─ contactPhone: Edm.String
├─ dpaUrl: Edm.String (Data Processing Agreement URL)
├─ dpaSignedDate: Edm.DateTimeOffset
├─ certifications: Collection(Edm.String)
│  └─ Examples: ISO27001, SOC2, GDPR-EduCompli
├─ lastAuditDate: Edm.DateTimeOffset
├─ nextAuditDueDate: Edm.DateTimeOffset
├─ riskRating: Edm.String
│  └─ Enum: Low, Medium, High, Critical
├─ status: Edm.String
│  └─ Enum: Active, Suspended, Revoked
└─ Relationships
   └─ ProcessingActivities: NavigationProperty → ProcessingActivity (1:*)
```

**Operations**:
- `GET /Processors` - List all processors
- `GET /Processors('{id}')` - Get processor details
- `POST /Processors` - Register new processor
- `PATCH /Processors('{id}')` - Update processor info
- `DELETE /Processors('{id}')` - Deactivate processor
- `POST /Processors('{id}')/scheduleAudit` - Schedule compliance audit

## 🔄 Function Imports & Actions

### Function Imports (Read-Only)

```
GET /GetDataSubjectExportFile(id='{id}')
  Returns: Binary (ZIP file)
  Description: Generate downloadable export of all subject data

GET /GetComplianceReport(year={year}, organization='{org}')
  Returns: Edm.Stream (PDF Report)
  Description: Generate annual compliance report

GET /CalculateRisk(activityId='{id}')
  Returns: RiskAssessmentResult
  Description: Calculate risk score for processing activity

GET /ValidateConsentProof(consentId='{id}')
  Returns: Edm.Boolean
  Description: Validate consent proof signature and timestamp
```

### Actions (Write Operations)

```
POST /DataSubjects('{id}')/RequestAccess
  Input: { format: 'JSON'|'CSV'|'PDF', deliveryMethod: 'Email'|'Download' }
  Returns: DataRequest
  Description: Initiate access request

POST /DataSubjects('{id}')/RequestErasure
  Input: { reason?: string }
  Returns: DataRequest
  Description: Initiate erasure request

POST /DataSubjects('{id}')/ExportData
  Input: { format: 'JSON'|'XML'|'CSV', includeArchived: boolean }
  Returns: Edm.Stream (File)
  Description: Export all personal data

POST /ConsentRecords('{id}')/Withdraw
  Input: { reason?: string }
  Returns: ConsentRecord
  Description: Withdraw consent

POST /ConsentRecords('{id}')/Renew
  Input: { renewalReason: string }
  Returns: ConsentRecord
  Description: Renew existing consent

POST /DataRequests('{id}')/Approve
  Input: { approverNotes: string }
  Returns: DataRequest
  Description: Approve a pending request

POST /DataRequests('{id}')/Reject
  Input: { rejectionReason: string }
  Returns: DataRequest
  Description: Reject a request

POST /DataRequests('{id}')/Complete
  Input: { completionNotes: string }
  Returns: DataRequest
  Description: Mark request as completed

POST /ProcessingActivities('{id}')/AssessRisk
  Input: {}
  Returns: RiskAssessmentResult
  Description: Perform risk assessment
```

## 🔍 Query Capabilities

### Standard Query Options

| Option | Support | Example |
|--------|---------|---------|
| `$filter` | ✓ | `/DataRequests?$filter=status eq 'Pending'` |
| `$select` | ✓ | `/DataSubjects?$select=id,email,firstName` |
| `$expand` | ✓ | `/DataSubjects('{id}')?$expand=Consents,Requests` |
| `$orderby` | ✓ | `/DataRequests?$orderby=submittedAt desc` |
| `$top` | ✓ | `/DataSubjects?$top=100` |
| `$skip` | ✓ | `/DataSubjects?$skip=50&$top=50` |
| `$count` | ✓ | `/DataRequests?$count=true` |
| `$search` | ✓ | `/DataSubjects?$search="John Doe"` |

### Filter Operators

```
# Comparison operators
eq, ne, gt, ge, lt, le

# Logical operators
and, or, not

# Functions
contains(property, 'value')
startswith(property, 'prefix')
endswith(property, 'suffix')
length(property)
year(property), month(property), day(property)
now(), today()

# Examples
GET /DataRequests?$filter=year(submittedAt) eq 2024 and status eq 'Completed'
GET /DataSubjects?$filter=contains(email, '@company.com')
GET /ConsentRecords?$filter=withdrawnAt eq null and status eq 'Granted'
```

## 📊 Batch Processing

The service supports batch operations via `$batch`:

```http
POST /odata/v4/gdpr/$batch

--batch_boundary
Content-Type: application/http
Content-Transfer-Encoding: binary

POST /DataSubjects HTTP/1.1
Content-Type: application/json

{
  "email": "john@example.com",
  "firstName": "John",
  "lastName": "Doe"
}

--batch_boundary
GET /DataRequests?$filter=status eq 'Pending' HTTP/1.1

--batch_boundary--
```

## 🔐 Security & Authentication

**Authentication Methods**:
- OAuth 2.0 / OpenID Connect (Primary)
- JWT Bearer Token
- API Key (Legacy)

**Required Headers**:
```
Authorization: Bearer {access_token}
Content-Type: application/json
X-Client-ID: {client_id}
```

**Scopes**:
- `gdpr:read` - Read access to data
- `gdpr:write` - Create/update operations
- `gdpr:delete` - Deletion operations
- `gdpr:admin` - Administrative functions
- `gdpr:audit` - Access audit logs

## 📝 Response Format

### Success Response (200 OK)

```json
{
  "@odata.context": "https://api.gdpr.company.com/odata/v4/gdpr/$metadata#DataSubjects/$entity",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "john@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "status": "Active",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-11-18T19:18:01Z"
}
```

### Collection Response

```json
{
  "@odata.context": "https://api.gdpr.company.com/odata/v4/gdpr/$metadata#DataSubjects",
  "@odata.count": 150,
  "value": [
    { /* entities */ }
  ],
  "@odata.nextLink": "https://api.gdpr.company.com/odata/v4/gdpr/DataSubjects?$skip=50"
}
```

### Error Response (400+ Status)

```json
{
  "error": {
    "code": "GDPR_INVALID_REQUEST",
    "message": "Invalid request: missing required field 'email'",
    "details": [
      {
        "code": "MISSING_FIELD",
        "message": "Field 'email' is required",
        "target": "email"
      }
    ]
  }
}
```

## 🧪 Example Workflows

### Complete Data Access Request Flow

```
1. Submit Request
   POST /DataSubjects('{id}')/RequestAccess
   Input: { format: 'JSON', deliveryMethod: 'Email' }
   → Returns: DataRequest { id: 'req-123', status: 'Submitted' }

2. Check Status
   GET /DataRequests('req-123')
   → Returns: DataRequest { status: 'UnderReview', dueDate: '2024-12-18' }

3. Admin Approves
   POST /DataRequests('req-123')/Approve
   Input: { approverNotes: 'Approved by DPO' }
   → Returns: DataRequest { status: 'Approved' }

4. System Processes
   Processing occurs asynchronously
   Status updates to 'Completed'

5. User Downloads
   GET /DataRequests('req-123')/download
   → Returns: Binary file (JSON export)
```

### Consent Management Flow

```
1. User Grants Consent
   POST /ConsentRecords
   Body: {
     "subjectId": "subj-123",
     "category": "Marketing",
     "type": "Explicit",
     "ipAddress": "192.168.1.1"
   }
   → Returns: ConsentRecord { id: 'cons-456', status: 'Granted' }

2. Query Consent Status
   GET /ConsentRecords?$filter=subjectId eq 'subj-123' and status eq 'Granted'

3. Withdraw Consent
   POST /ConsentRecords('cons-456')/Withdraw
   Input: { reason: 'User requested withdrawal' }
   → Updates status to 'Withdrawn', sets withdrawnAt timestamp
```

## 📈 Performance & Pagination

Default page size: **50 entities**  
Maximum page size: **1000 entities**

```
# Efficient pagination
GET /DataRequests?$top=100&$skip=200&$select=id,type,status&$orderby=submittedAt desc
```

## 🔄 Versioning

Current Version: **1.0.0**  
API Version Header: `X-API-Version: 1.0.0`

---

**Last Updated**: November 2026  
**OData Specification Version**: 4.0  
**Status**: Production Ready
