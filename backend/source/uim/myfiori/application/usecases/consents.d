module uim.myfiori.application.usecases.consents;

@safe:

import std.algorithm : filter, map, sort;
import std.array : array;
import std.string : toLower;
import uim.myfiori.application.dtos;
import uim.myfiori.application.services;
import uim.myfiori.application.usecases.common;
import uim.myfiori.domain;
import uim.myfiori.ports;

class DConsentUseCases : IConsentUseCases {
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

  ConsentDto[] list(string projectId = "", string subjectEmail = "") {
    auto email = subjectEmail.toLower;
    return scoped(_consents, _projects, projectId)
      .filter!(c => email.length == 0 || c.subjectEmail.toLower == email).array
      .sort!((a, b) => a.givenAt > b.givenAt)
      .map!(c => toDto(c)).array;
  }

  ConsentDto get(string id) { return toDto(load(_consents, id, "Consent")); }

  ConsentDto give(CreateConsentInput i) {
    writableProject(_projects, i.projectId);
    checkActivity(i.projectId, i.activityId);
    auto c = DConsent.give(newId("", (string id) => _consents.exists(id)), i.projectId, i.activityId, i.subjectEmail,
        i.purpose, i.textVersion, parseEnum!ConsentChannel(i.channel, "channel"), parseTimestamp(i.givenAt, "givenAt"));
    _consents.save(c);
    emit(_events, "ConsentGiven", c.id, c.projectId, c.purpose);
    return toDto(c);
  }

  ConsentDto update(string id, UpdateConsentInput i) {
    auto c = load(_consents, id, "Consent");
    writableProject(_projects, c.projectId);
    if (!i.activityId.isNull) {
      checkActivity(c.projectId, i.activityId.get);
      c.relateTo(i.activityId.get);
    }
    if (!i.purpose.isNull || !i.textVersion.isNull)
      c.restatePurpose(i.purpose.isNull ? c.purpose : i.purpose.get, i.textVersion.isNull ? c.textVersion : i.textVersion.get);
    _consents.save(c);
    emit(_events, "ConsentUpdated", c.id, c.projectId);
    return toDto(c);
  }

  ConsentDto withdraw(string id, string at = "") {
    auto c = load(_consents, id, "Consent");
    writableProject(_projects, c.projectId);
    auto t = parseTimestamp(at, "withdrawnAt");
    if (!t.isNull && t.get > now) throw new ValidationException("withdrawnAt must not be in the future");
    c.withdraw(t.isNull ? now : t.get);
    _consents.save(c);
    emit(_events, "ConsentWithdrawn", c.id, c.projectId, c.purpose);
    return toDto(c);
  }

  void remove(string id) {
    auto c = load(_consents, id, "Consent");
    writableProject(_projects, c.projectId);
    _consents.remove(id);
    emit(_events, "ConsentDeleted", id, c.projectId);
  }

  /// A consent may only refer to a consent-based activity of the same project.
  private void checkActivity(string projectId, string activityId) {
    if (activityId.length == 0) return;
    auto a = load(_activities, activityId, "ProcessingActivity");
    if (a.projectId != projectId)
      throw new ValidationException("Processing activity '" ~ a.name ~ "' belongs to another project");
    if (a.legalBasis != LegalBasis.consent)
      throw new ValidationException("Processing activity '" ~ a.name ~ "' is not based on consent (Art. 6 (1) a)");
  }
}
