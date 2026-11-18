/// Converters between storage records and domain entities.
module uim.myfiori.persistence.mappers;

@safe:

import std.conv : to;
import std.datetime.date : Date;
import std.datetime.systime : SysTime;
import uim.myfiori.domain;
import uim.myfiori.persistence.records;

private SysTime ts(string v) { return parseTimestamp(v, "timestamp").get; }
private Date dt(string v) { return parseDate(v, "date").get; }

ProjectRecord toRecord(const DProject p) {
  return ProjectRecord(recordSchema, p.id, p.name, p.description, p.controller, p.dpoName, p.dpoEmail,
      p.status.to!string, isoTimestamp(p.createdAt), isoTimestamp(p.modifiedAt));
}

DProject toEntity(ProjectRecord r) {
  return new DProject(r.id, r.name, r.description, r.controller, r.dpoName, r.dpoEmail,
      parseEnum!ProjectStatus(r.status, "status"), ts(r.createdAt), ts(r.modifiedAt));
}

ProcessingActivityRecord toRecord(const DProcessingActivity a) {
  return ProcessingActivityRecord(recordSchema, a.id, a.projectId, a.name, a.purpose, a.legalBasis.to!string,
      a.dataCategories, a.dataSubjects, a.recipients, a.retentionPeriod, a.toms, a.specialCategories, a.largeScale,
      a.systematicMonitoring, a.automatedDecisions, a.thirdCountryTransfer, a.transferSafeguard, a.dpiaCompleted,
      a.status.to!string, isoTimestamp(a.createdAt), isoTimestamp(a.modifiedAt));
}

DProcessingActivity toEntity(ProcessingActivityRecord r) {
  return new DProcessingActivity(r.id, r.projectId, r.name, r.purpose, parseEnum!LegalBasis(r.legalBasis, "legalBasis"),
      r.dataCategories, r.dataSubjects, r.recipients, r.retentionPeriod, r.toms, r.specialCategories, r.largeScale,
      r.systematicMonitoring, r.automatedDecisions, r.thirdCountryTransfer, r.transferSafeguard, r.dpiaCompleted,
      parseEnum!ActivityStatus(r.status, "status"), ts(r.createdAt), ts(r.modifiedAt));
}

DataSubjectRequestRecord toRecord(const DDataSubjectRequest q) {
  return DataSubjectRequestRecord(recordSchema, q.id, q.projectId, q.type.to!string, q.subjectName, q.subjectEmail,
      q.description, q.receivedOn.toISOExtString, q.extended, q.extensionReason, q.status.to!string, q.resolution,
      isoDate(q.closedOn), isoTimestamp(q.createdAt), isoTimestamp(q.modifiedAt));
}

DDataSubjectRequest toEntity(DataSubjectRequestRecord r) {
  return new DDataSubjectRequest(r.id, r.projectId, parseEnum!RequestType(r.type, "type"), r.subjectName,
      r.subjectEmail, r.description, dt(r.receivedOn), r.extended, r.extensionReason,
      parseEnum!RequestStatus(r.status, "status"), r.resolution, parseDate(r.closedOn, "closedOn"),
      ts(r.createdAt), ts(r.modifiedAt));
}

DataBreachRecord toRecord(const DDataBreach b) {
  return DataBreachRecord(recordSchema, b.id, b.projectId, b.title, b.description, isoTimestamp(b.detectedAt),
      b.severity.to!string, b.affectedSubjects, b.dataCategories, b.measures, b.status.to!string,
      isoTimestamp(b.reportedAt), isoTimestamp(b.subjectsNotifiedAt), isoTimestamp(b.createdAt), isoTimestamp(b.modifiedAt));
}

DDataBreach toEntity(DataBreachRecord r) {
  return new DDataBreach(r.id, r.projectId, r.title, r.description, ts(r.detectedAt),
      parseEnum!BreachSeverity(r.severity, "severity"), r.affectedSubjects, r.dataCategories, r.measures,
      parseEnum!BreachStatus(r.status, "status"), parseTimestamp(r.reportedAt, "reportedAt"),
      parseTimestamp(r.subjectsNotifiedAt, "subjectsNotifiedAt"), ts(r.createdAt), ts(r.modifiedAt));
}

ConsentRecord toRecord(const DConsent c) {
  return ConsentRecord(recordSchema, c.id, c.projectId, c.activityId, c.subjectEmail, c.purpose, c.textVersion,
      c.channel.to!string, isoTimestamp(c.givenAt), isoTimestamp(c.withdrawnAt), isoTimestamp(c.createdAt),
      isoTimestamp(c.modifiedAt));
}

DConsent toEntity(ConsentRecord r) {
  return new DConsent(r.id, r.projectId, r.activityId, r.subjectEmail, r.purpose, r.textVersion,
      parseEnum!ConsentChannel(r.channel, "channel"), ts(r.givenAt), parseTimestamp(r.withdrawnAt, "withdrawnAt"),
      ts(r.createdAt), ts(r.modifiedAt));
}
