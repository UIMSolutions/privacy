/// Driven ports for business data access (one repository per aggregate).
module uim.myfiori.ports.repositories;

@safe:

import uim.myfiori.domain.entities;
import uim.myfiori.domain.types : EntityId;

interface IRepository(T) {
  T[] all();
  /// null if the aggregate does not exist
  T find(EntityId id);
  bool exists(EntityId id);
  void save(T entity);
  bool remove(EntityId id);
}

/// Repository of aggregates that belong to a project.
interface IProjectScopedRepository(T) : IRepository!T {
  T[] byProject(EntityId projectId);
}

alias IProjectRepository = IRepository!DProject;
alias IProcessingActivityRepository = IProjectScopedRepository!DProcessingActivity;
alias IDataSubjectRequestRepository = IProjectScopedRepository!DDataSubjectRequest;
alias IDataBreachRepository = IProjectScopedRepository!DDataBreach;
alias IConsentRepository = IProjectScopedRepository!DConsent;
