/// Entity → DTO mapping (including derived values that depend on the deadline policy).
module uim.myfiori.application.services.dtomapping;

@safe:

import std.conv : to;
import std.typecons : Nullable;
import uim.myfiori.application.dtos;
import uim.myfiori.domain;

ProjectDto toDto(const DProject p) {
  return ProjectDto(p.id, p.name, p.description, p.controller, p.dpoName, p.dpoEmail, p.status.to!string,
      isoTimestamp(p.createdAt), isoTimestamp(p.modifiedAt));
}

ProcessingActivityDto toDto(const DProcessingActivity a) {
  ProcessingActivityDto d;
  d.ID = a.id;
  d.projectId = a.projectId;
  d.name = a.name;
  d.purpose = a.purpose;
  d.legalBasis = a.legalBasis.to!string;
  d.legalBasisArticle = article(a.legalBasis);
  d.dataCategories = a.dataCategories;
  d.dataSubjects = a.dataSubjects;
  d.recipients = a.recipients;
  d.retentionPeriod = a.retentionPeriod;
  d.toms = a.toms;
  d.specialCategories = a.specialCategories;
  d.largeScale = a.largeScale;
  d.systematicMonitoring = a.systematicMonitoring;
  d.automatedDecisions = a.automatedDecisions;
  d.thirdCountryTransfer = a.thirdCountryTransfer;
  d.transferSafeguard = a.transferSafeguard;
  d.dpiaCompleted = a.dpiaCompleted;
  d.dpiaRequired = a.dpiaRequired;
  d.riskLevel = a.riskLevel.to!string;
  d.status = a.status.to!string;
  d.createdAt = isoTimestamp(a.createdAt);
  d.modifiedAt = isoTimestamp(a.modifiedAt);
  return d;
}

DataSubjectRequestDto toDto(const DDataSubjectRequest r, DeadlinePolicy p) {
  auto day = today;
  DataSubjectRequestDto d;
  d.ID = r.id;
  d.projectId = r.projectId;
  d.type = r.type.to!string;
  d.article = article(r.type);
  d.subjectName = r.subjectName;
  d.subjectEmail = r.subjectEmail;
  d.description = r.description;
  d.receivedOn = r.receivedOn.toISOExtString;
  d.dueDate = r.dueDate(p).toISOExtString;
  d.extended = r.extended;
  d.extensionReason = r.extensionReason;
  d.status = r.status.to!string;
  d.resolution = r.resolution;
  d.closedOn = isoDate(r.closedOn);
  d.overdue = r.overdue(p, day);
  d.daysLeft = cast(int) r.daysLeft(p, day);
  d.createdAt = isoTimestamp(r.createdAt);
  d.modifiedAt = isoTimestamp(r.modifiedAt);
  return d;
}

DataBreachDto toDto(const DDataBreach b, DeadlinePolicy p) {
  auto at = now;
  DataBreachDto d;
  d.ID = b.id;
  d.projectId = b.projectId;
  d.title = b.title;
  d.description = b.description;
  d.detectedAt = isoTimestamp(b.detectedAt);
  d.severity = b.severity.to!string;
  d.affectedSubjects = b.affectedSubjects;
  d.dataCategories = b.dataCategories;
  d.measures = b.measures;
  d.status = b.status.to!string;
  d.reportedAt = isoTimestamp(b.reportedAt);
  d.subjectsNotifiedAt = isoTimestamp(b.subjectsNotifiedAt);
  d.notificationDeadline = isoTimestamp(b.notificationDeadline(p));
  d.authorityNotificationRequired = b.authorityNotificationRequired;
  d.subjectNotificationRequired = b.subjectNotificationRequired;
  d.deadlineMissed = b.deadlineMissed(p, at);
  d.hoursLeft = cast(int) b.hoursLeft(p, at);
  d.createdAt = isoTimestamp(b.createdAt);
  d.modifiedAt = isoTimestamp(b.modifiedAt);
  return d;
}

ConsentDto toDto(const DConsent c) {
  return ConsentDto(c.id, c.projectId, c.activityId, c.subjectEmail, c.purpose, c.textVersion, c.channel.to!string,
      isoTimestamp(c.givenAt), isoTimestamp(c.withdrawnAt), c.active, isoTimestamp(c.createdAt), isoTimestamp(c.modifiedAt));
}
