module uim.myfiori.application.usecases.activities;

@safe:

import std.algorithm : any, map, sort;
import std.array : array;
import uim.myfiori.application.dtos;
import uim.myfiori.application.services;
import uim.myfiori.application.usecases.common;
import uim.myfiori.domain;
import uim.myfiori.ports;

class DProcessingActivityUseCases : IProcessingActivityUseCases {
  private IProjectRepository _projects;
  private IProcessingActivityRepository _activities;
  private IConsentRepository _consents;
  private IDomainEventPublisher _events;

  this(IProjectRepository projects, IProcessingActivityRepository activities, IConsentRepository consents,
      IDomainEventPublisher events) {
    _projects = projects;
    _activities = activities;
    _consents = consents;
    _events = events;
  }

  ProcessingActivityDto[] list(string projectId = "") {
    return scoped(_activities, _projects, projectId).sort!((a, b) => a.name < b.name).map!(a => toDto(a)).array;
  }

  ProcessingActivityDto get(string id) { return toDto(load(_activities, id, "ProcessingActivity")); }

  ProcessingActivityDto create(CreateActivityInput i) {
    writableProject(_projects, i.projectId);
    auto a = DProcessingActivity.create(newId("", (string id) => _activities.exists(id)), i.projectId, i.name,
        i.purpose, parseEnum!LegalBasis(i.legalBasis, "legalBasis"));
    a.describeData(i.dataCategories, i.dataSubjects, i.recipients);
    a.retainFor(i.retentionPeriod);
    a.protectWith(i.toms);
    a.classify(i.specialCategories, i.largeScale, i.systematicMonitoring, i.automatedDecisions);
    a.transfer(i.thirdCountryTransfer, i.transferSafeguard);
    a.recordDpia(i.dpiaCompleted);
    a.changeStatus(parseEnum!ActivityStatus(i.status, "status"));
    _activities.save(a);
    emit(_events, "ProcessingActivityCreated", a.id, a.projectId, a.name);
    return toDto(a);
  }

  ProcessingActivityDto update(string id, UpdateActivityInput i) {
    auto a = load(_activities, id, "ProcessingActivity");
    writableProject(_projects, a.projectId);
    // status changes towards draft/retired first, activation last (it validates the final record)
    Nullable!ActivityStatus target;
    if (!i.status.isNull) target = parseEnum!ActivityStatus(i.status.get, "status");
    if (!target.isNull && target.get != ActivityStatus.active) a.changeStatus(target.get);

    if (!i.name.isNull) a.rename(i.name.get);
    if (!i.purpose.isNull) a.describePurpose(i.purpose.get);
    if (!i.legalBasis.isNull) a.baseOn(parseEnum!LegalBasis(i.legalBasis.get, "legalBasis"));
    if (!i.dataCategories.isNull || !i.dataSubjects.isNull || !i.recipients.isNull)
      a.describeData(pick(i.dataCategories, a.dataCategories), pick(i.dataSubjects, a.dataSubjects),
          pick(i.recipients, a.recipients));
    if (!i.retentionPeriod.isNull) a.retainFor(i.retentionPeriod.get);
    if (!i.toms.isNull) a.protectWith(i.toms.get);
    if (!i.specialCategories.isNull || !i.largeScale.isNull || !i.systematicMonitoring.isNull || !i.automatedDecisions.isNull)
      a.classify(pick(i.specialCategories, a.specialCategories), pick(i.largeScale, a.largeScale),
          pick(i.systematicMonitoring, a.systematicMonitoring), pick(i.automatedDecisions, a.automatedDecisions));
    if (!i.thirdCountryTransfer.isNull || !i.transferSafeguard.isNull)
      a.transfer(pick(i.thirdCountryTransfer, a.thirdCountryTransfer), pick(i.transferSafeguard, a.transferSafeguard));
    if (!i.dpiaCompleted.isNull) a.recordDpia(i.dpiaCompleted.get);

    if (!target.isNull && target.get == ActivityStatus.active && a.status != ActivityStatus.active) a.activate;
    _activities.save(a);
    emit(_events, "ProcessingActivityUpdated", a.id, a.projectId, a.status.to!string);
    return toDto(a);
  }

  void remove(string id) {
    auto a = load(_activities, id, "ProcessingActivity");
    writableProject(_projects, a.projectId);
    if (_consents.byProject(a.projectId).any!(c => c.activityId == id))
      throw new ConflictException("Activity '" ~ a.name ~ "' is referenced by consents; retire it instead");
    _activities.remove(id);
    emit(_events, "ProcessingActivityDeleted", id, a.projectId, a.name);
  }
}

private T pick(T)(Nullable!T v, T current) { return v.isNull ? current : v.get; }

import std.conv : to;
import std.typecons : Nullable;
