module uim.myfiori.application.usecases.requests;

@safe:

import std.algorithm : map, sort;
import std.array : array;
import std.conv : to;
import uim.myfiori.application.dtos;
import uim.myfiori.application.services;
import uim.myfiori.application.usecases.common;
import uim.myfiori.domain;
import uim.myfiori.ports;

class DDataSubjectRequestUseCases : IDataSubjectRequestUseCases {
  private IProjectRepository _projects;
  private IDataSubjectRequestRepository _requests;
  private IDomainEventPublisher _events;
  private DeadlinePolicy _policy;

  this(IProjectRepository projects, IDataSubjectRequestRepository requests, IDomainEventPublisher events,
      DeadlinePolicy policy) {
    _projects = projects;
    _requests = requests;
    _events = events;
    _policy = policy;
  }

  DataSubjectRequestDto[] list(string projectId = "") {
    // open requests first, ordered by deadline
    auto p = _policy;
    return scoped(_requests, _projects, projectId)
      .sort!((a, b) => a.closed != b.closed ? !a.closed : a.dueDate(p) < b.dueDate(p))
      .map!(r => toDto(r, p)).array;
  }

  DataSubjectRequestDto get(string id) { return toDto(load(_requests, id, "DataSubjectRequest"), _policy); }

  DataSubjectRequestDto create(CreateRequestInput i) {
    writableProject(_projects, i.projectId);
    auto r = DDataSubjectRequest.create(newId("", (string id) => _requests.exists(id)), i.projectId,
        parseEnum!RequestType(i.type, "type"), i.subjectName, i.subjectEmail, i.description,
        parseDate(i.receivedOn, "receivedOn"));
    _requests.save(r);
    emit(_events, "DataSubjectRequestReceived", r.id, r.projectId, r.type.to!string ~ " due " ~ r.dueDate(_policy).toISOExtString);
    return toDto(r, _policy);
  }

  DataSubjectRequestDto update(string id, UpdateRequestInput i) {
    auto r = load(_requests, id, "DataSubjectRequest");
    writableProject(_projects, r.projectId);
    if (!i.subjectName.isNull || !i.subjectEmail.isNull)
      r.correctSubject(i.subjectName.isNull ? r.subjectName : i.subjectName.get,
          i.subjectEmail.isNull ? r.subjectEmail : i.subjectEmail.get);
    if (!i.description.isNull) r.describe(i.description.get);
    auto resolution = i.resolution.isNull ? "" : i.resolution.get;
    if (!i.status.isNull) r.advance(parseEnum!RequestStatus(i.status.get, "status"), resolution);
    else if (resolution.length) r.advance(r.status, resolution);
    _requests.save(r);
    emit(_events, "DataSubjectRequestUpdated", r.id, r.projectId, r.status.to!string);
    return toDto(r, _policy);
  }

  DataSubjectRequestDto extend(string id, string reason) {
    auto r = load(_requests, id, "DataSubjectRequest");
    writableProject(_projects, r.projectId);
    r.extend(reason);
    _requests.save(r);
    emit(_events, "DataSubjectRequestExtended", r.id, r.projectId, "new due date " ~ r.dueDate(_policy).toISOExtString);
    return toDto(r, _policy);
  }

  void remove(string id) {
    auto r = load(_requests, id, "DataSubjectRequest");
    writableProject(_projects, r.projectId);
    _requests.remove(id);
    emit(_events, "DataSubjectRequestDeleted", id, r.projectId);
  }
}
