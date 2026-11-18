/**
 * Data transfer objects. Field names are the external names (OData properties,
 * JSON, CSV columns, CLI options). Dates are ISO 8601 strings ("" = not set).
 * Update inputs use Nullable fields: null = leave unchanged.
 */
module uim.myfiori.application.dtos;

@safe:

import std.typecons : Nullable;

// ------------------------------------------------------------------ read models

struct ProjectDto {
  string ID;
  string name;
  string description;
  string controller;
  string dpoName;
  string dpoEmail;
  string status;
  string createdAt;
  string modifiedAt;
}

struct ProcessingActivityDto {
  string ID;
  string projectId;
  string name;
  string purpose;
  string legalBasis;
  string legalBasisArticle;
  string dataCategories;
  string dataSubjects;
  string recipients;
  string retentionPeriod;
  string toms;
  bool specialCategories;
  bool largeScale;
  bool systematicMonitoring;
  bool automatedDecisions;
  bool thirdCountryTransfer;
  string transferSafeguard;
  bool dpiaCompleted;
  bool dpiaRequired;
  string riskLevel;
  string status;
  string createdAt;
  string modifiedAt;
}

struct DataSubjectRequestDto {
  string ID;
  string projectId;
  string type;
  string article;
  string subjectName;
  string subjectEmail;
  string description;
  string receivedOn;
  string dueDate;
  bool extended;
  string extensionReason;
  string status;
  string resolution;
  string closedOn;
  bool overdue;
  int daysLeft;
  string createdAt;
  string modifiedAt;
}

struct DataBreachDto {
  string ID;
  string projectId;
  string title;
  string description;
  string detectedAt;
  string severity;
  int affectedSubjects;
  string dataCategories;
  string measures;
  string status;
  string reportedAt;
  string subjectsNotifiedAt;
  string notificationDeadline;
  bool authorityNotificationRequired;
  bool subjectNotificationRequired;
  bool deadlineMissed;
  int hoursLeft;
  string createdAt;
  string modifiedAt;
}

struct ConsentDto {
  string ID;
  string projectId;
  string activityId;
  string subjectEmail;
  string purpose;
  string textVersion;
  string channel;
  string givenAt;
  string withdrawnAt;
  bool active;
  string createdAt;
  string modifiedAt;
}

struct FindingDto {
  string severity;
  string article;
  string text;
}

/// Compliance dashboard of one project.
struct ProjectReportDto {
  string projectId;
  string projectName;
  string status;
  int activitiesTotal;
  int activitiesActive;
  int activitiesHighRisk;
  int dpiaRequired;
  int dpiaOpen;
  int transfersWithoutSafeguard;
  int requestsTotal;
  int requestsOpen;
  int requestsOverdue;
  int breachesTotal;
  int breachesOpen;
  int breachesNotReported;
  int breachesDeadlineMissed;
  int consentsTotal;
  int consentsActive;
  int consentsWithdrawn;
  double complianceScore;
  FindingDto[] findings;
}

/// An upcoming or missed statutory deadline.
struct DeadlineAlertDto {
  string kind;          // request | breach
  string entityId;
  string projectId;
  string projectName;
  string recipient;     // DPO e-mail
  string title;
  string deadline;      // ISO date / timestamp
  bool missed;
  long remaining;       // days (request) or hours (breach); negative when missed
}

// ------------------------------------------------------------------ inputs

struct CreateProjectInput {
  string name;
  string description;
  string controller;
  string dpoName;
  string dpoEmail;
}

struct UpdateProjectInput {
  Nullable!string name;
  Nullable!string description;
  Nullable!string controller;
  Nullable!string dpoName;
  Nullable!string dpoEmail;
  Nullable!string status;
}

struct CreateActivityInput {
  string projectId;
  string name;
  string purpose;
  string legalBasis = "contract";
  string dataCategories;
  string dataSubjects;
  string recipients;
  string retentionPeriod;
  string toms;
  bool specialCategories;
  bool largeScale;
  bool systematicMonitoring;
  bool automatedDecisions;
  bool thirdCountryTransfer;
  string transferSafeguard;
  bool dpiaCompleted;
  string status = "draft";
}

struct UpdateActivityInput {
  Nullable!string name;
  Nullable!string purpose;
  Nullable!string legalBasis;
  Nullable!string dataCategories;
  Nullable!string dataSubjects;
  Nullable!string recipients;
  Nullable!string retentionPeriod;
  Nullable!string toms;
  Nullable!bool specialCategories;
  Nullable!bool largeScale;
  Nullable!bool systematicMonitoring;
  Nullable!bool automatedDecisions;
  Nullable!bool thirdCountryTransfer;
  Nullable!string transferSafeguard;
  Nullable!bool dpiaCompleted;
  Nullable!string status;
}

struct CreateRequestInput {
  string projectId;
  string type;
  string subjectName;
  string subjectEmail;
  string description;
  string receivedOn;      // default: today
}

struct UpdateRequestInput {
  Nullable!string subjectName;
  Nullable!string subjectEmail;
  Nullable!string description;
  Nullable!string status;
  Nullable!string resolution;
}

struct CreateBreachInput {
  string projectId;
  string title;
  string description;
  string detectedAt;      // default: now
  string severity = "medium";
  int affectedSubjects;
  string dataCategories;
  string measures;
}

struct UpdateBreachInput {
  Nullable!string title;
  Nullable!string description;
  Nullable!string severity;
  Nullable!int affectedSubjects;
  Nullable!string dataCategories;
  Nullable!string measures;
}

struct CreateConsentInput {
  string projectId;
  string activityId;
  string subjectEmail;
  string purpose;
  string textVersion;
  string channel = "web";
  string givenAt;         // default: now
}

struct UpdateConsentInput {
  Nullable!string activityId;
  Nullable!string purpose;
  Nullable!string textVersion;
}
