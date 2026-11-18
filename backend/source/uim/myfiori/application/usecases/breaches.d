module uim.myfiori.application.usecases.breaches;

@safe:

import std.algorithm : map, sort;
import std.array : array;
import std.conv : to;
import std.datetime.systime : SysTime;
import uim.myfiori.application.dtos;
import uim.myfiori.application.services;
import uim.myfiori.application.usecases.common;
import uim.myfiori.domain;
import uim.myfiori.ports;

class DDataBreachUseCases : IDataBreachUseCases {
  private IProjectRepository _projects;
  private IDataBreachRepository _breaches;
  private IDomainEventPublisher _events;
  private DeadlinePolicy _policy;

  this(IProjectRepository projects, IDataBreachRepository breaches, IDomainEventPublisher events, DeadlinePolicy policy) {
    _projects = projects;
    _breaches = breaches;
    _events = events;
    _policy = policy;
  }

  DataBreachDto[] list(string projectId = "") {
    auto p = _policy;
    return scoped(_breaches, _projects, projectId)
      .sort!((a, b) => a.detectedAt > b.detectedAt)
      .map!(b => toDto(b, p)).array;
  }

  DataBreachDto get(string id) { return toDto(load(_breaches, id, "DataBreach"), _policy); }

  DataBreachDto create(CreateBreachInput i) {
    writableProject(_projects, i.projectId);
    auto b = DDataBreach.create(newId("", (string id) => _breaches.exists(id)), i.projectId, i.title, i.description,
        parseTimestamp(i.detectedAt, "detectedAt"), parseEnum!BreachSeverity(i.severity, "severity"), i.affectedSubjects);
    b.documentData(i.dataCategories);
    b.documentMeasures(i.measures);
    _breaches.save(b);
    emit(_events, "DataBreachRecorded", b.id, b.projectId,
        b.severity.to!string ~ (b.authorityNotificationRequired
          ? ", notify authority by " ~ isoTimestamp(b.notificationDeadline(_policy)) : ", no notification required"));
    return toDto(b, _policy);
  }

  DataBreachDto update(string id, UpdateBreachInput i) {
    auto b = load(_breaches, id, "DataBreach");
    writableProject(_projects, b.projectId);
    if (!i.title.isNull) b.retitle(i.title.get);
    if (!i.description.isNull) b.describe(i.description.get);
    if (!i.severity.isNull || !i.affectedSubjects.isNull)
      b.assess(i.severity.isNull ? b.severity : parseEnum!BreachSeverity(i.severity.get, "severity"),
          i.affectedSubjects.isNull ? b.affectedSubjects : i.affectedSubjects.get);
    if (!i.dataCategories.isNull) b.documentData(i.dataCategories.get);
    if (!i.measures.isNull) b.documentMeasures(i.measures.get);
    _breaches.save(b);
    emit(_events, "DataBreachUpdated", b.id, b.projectId);
    return toDto(b, _policy);
  }

  DataBreachDto reportToAuthority(string id, string at = "") {
    auto b = load(_breaches, id, "DataBreach");
    writableProject(_projects, b.projectId);
    b.reportToAuthority(timeOrNow(at, "reportedAt"));
    _breaches.save(b);
    emit(_events, "DataBreachReported", b.id, b.projectId, b.deadlineMissed(_policy, now) ? "after the deadline" : "in time");
    return toDto(b, _policy);
  }

  DataBreachDto notifySubjects(string id, string at = "") {
    auto b = load(_breaches, id, "DataBreach");
    writableProject(_projects, b.projectId);
    b.notifySubjects(timeOrNow(at, "subjectsNotifiedAt"));
    _breaches.save(b);
    emit(_events, "DataBreachSubjectsNotified", b.id, b.projectId);
    return toDto(b, _policy);
  }

  DataBreachDto close(string id) {
    auto b = load(_breaches, id, "DataBreach");
    writableProject(_projects, b.projectId);
    b.close;
    _breaches.save(b);
    emit(_events, "DataBreachClosed", b.id, b.projectId);
    return toDto(b, _policy);
  }

  void remove(string id) {
    auto b = load(_breaches, id, "DataBreach");
    writableProject(_projects, b.projectId);
    // Art. 33 (5): breaches must be documented – only open, unreported cases (e.g. false alarms) may be deleted
    if (b.status != BreachStatus.open || !b.reportedAt.isNull)
      throw new ConflictException("Reported or closed breaches must remain documented (Art. 33 (5))");
    _breaches.remove(id);
    emit(_events, "DataBreachDeleted", id, b.projectId);
  }

  private static SysTime timeOrNow(string at, string field) {
    auto t = parseTimestamp(at, field);
    if (!t.isNull && t.get > now) throw new ValidationException(field ~ " must not be in the future");
    return t.isNull ? now : t.get;
  }
}
