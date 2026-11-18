/**
 * Technical storage models (one JSON document per aggregate). Enumerations and
 * timestamps are stored as strings; `schema` allows future migrations.
 */
module uim.myfiori.persistence.records;

@safe:

enum recordSchema = 1;

/// Collection names in the document store.
enum Collections : string {
  projects = "projects",
  activities = "processingActivities",
  requests = "dataSubjectRequests",
  breaches = "dataBreaches",
  consents = "consents",
}

struct ProjectRecord {
  int schema = recordSchema;
  string id, name, description, controller, dpoName, dpoEmail, status, createdAt, modifiedAt;
}

struct ProcessingActivityRecord {
  int schema = recordSchema;
  string id, projectId, name, purpose, legalBasis, dataCategories, dataSubjects, recipients, retentionPeriod, toms;
  bool specialCategories, largeScale, systematicMonitoring, automatedDecisions, thirdCountryTransfer;
  string transferSafeguard;
  bool dpiaCompleted;
  string status, createdAt, modifiedAt;
}

struct DataSubjectRequestRecord {
  int schema = recordSchema;
  string id, projectId, type, subjectName, subjectEmail, description, receivedOn;
  bool extended;
  string extensionReason, status, resolution, closedOn, createdAt, modifiedAt;
}

struct DataBreachRecord {
  int schema = recordSchema;
  string id, projectId, title, description, detectedAt, severity;
  int affectedSubjects;
  string dataCategories, measures, status, reportedAt, subjectsNotifiedAt, createdAt, modifiedAt;
}

struct ConsentRecord {
  int schema = recordSchema;
  string id, projectId, activityId, subjectEmail, purpose, textVersion, channel, givenAt, withdrawnAt, createdAt, modifiedAt;
}
