/// Repository implementations on top of the document storage port.
module uim.myfiori.persistence.repositories;

@safe:

import std.algorithm : filter, map;
import std.array : array;
import vibe.data.json;
import uim.myfiori.domain.entities;
import uim.myfiori.persistence.mappers;
import uim.myfiori.persistence.records;
import uim.myfiori.ports.repositories;
import uim.myfiori.ports.storages;

/// Generic document repository: entity <-> record (mapper) <-> JSON document.
class DDocumentRepository(E, R) : IRepository!E {
  protected IDocumentStorage _storage;
  protected string _collection;

  this(IDocumentStorage storage, string collection) {
    _storage = storage;
    _collection = collection;
  }

  E[] all() { return _storage.all(_collection).map!(j => decode(j)).array; }

  E find(string id) {
    auto j = _storage.get(_collection, id);
    return j.type == Json.Type.undefined ? null : decode(j);
  }

  bool exists(string id) { return _storage.get(_collection, id).type != Json.Type.undefined; }

  void save(E e) @trusted { _storage.put(_collection, e.id, serializeToJson(toRecord(e))); }

  bool remove(string id) { return _storage.remove(_collection, id); }

  protected static E decode(Json j) @trusted { return toEntity(deserializeJson!R(j)); }
}

/// Repository for aggregates belonging to a project.
class DProjectScopedRepository(E, R) : DDocumentRepository!(E, R), IProjectScopedRepository!E {
  this(IDocumentStorage storage, string collection) { super(storage, collection); }

  E[] byProject(string projectId) {
    return _storage.all(_collection)
      .filter!(j => j["projectId"].opt!string == projectId)
      .map!(j => decode(j)).array;
  }
}

alias DProjectRepository = DDocumentRepository!(DProject, ProjectRecord);
alias DProcessingActivityRepository = DProjectScopedRepository!(DProcessingActivity, ProcessingActivityRecord);
alias DDataSubjectRequestRepository = DProjectScopedRepository!(DDataSubjectRequest, DataSubjectRequestRecord);
alias DDataBreachRepository = DProjectScopedRepository!(DDataBreach, DataBreachRecord);
alias DConsentRepository = DProjectScopedRepository!(DConsent, ConsentRecord);
