module uim.myfiori.application.usecases.projects;

@safe:

import std.algorithm : map, sort;
import std.array : array;
import uim.myfiori.application.dtos;
import uim.myfiori.application.services;
import uim.myfiori.application.usecases.common;
import uim.myfiori.domain;
import uim.myfiori.ports;

class DProjectUseCases : IProjectUseCases {
  private IProjectRepository _projects;
  private IProcessingActivityRepository _activities;
  private IDataSubjectRequestRepository _requests;
  private IDataBreachRepository _breaches;
  private IConsentRepository _consents;
  private IDomainEventPublisher _events;

  this(IProjectRepository projects, IProcessingActivityRepository activities, IDataSubjectRequestRepository requests,
      IDataBreachRepository breaches, IConsentRepository consents, IDomainEventPublisher events) {
    _projects = projects;
    _activities = activities;
    _requests = requests;
    _breaches = breaches;
    _consents = consents;
    _events = events;
  }

  ProjectDto[] list() {
    return _projects.all.sort!((a, b) => a.name < b.name).map!(p => toDto(p)).array;
  }

  ProjectDto get(string id) { return toDto(load(_projects, id, "Project")); }

  ProjectDto create(CreateProjectInput i) {
    auto p = DProject.create(newId("", (string id) => _projects.exists(id)), i.name, i.description, i.controller,
        i.dpoName, i.dpoEmail);
    _projects.save(p);
    emit(_events, "ProjectCreated", p.id, p.id, p.name);
    return toDto(p);
  }

  ProjectDto update(string id, UpdateProjectInput i) {
    auto p = load(_projects, id, "Project");
    // a status change (e.g. un-archiving) is applied first, so the other fields may change with it
    if (!i.status.isNull) p.changeStatus(parseEnum!ProjectStatus(i.status.get, "status"));
    if (!i.name.isNull) p.rename(i.name.get);
    if (!i.description.isNull) p.describe(i.description.get);
    if (!i.controller.isNull) p.assignController(i.controller.get);
    if (!i.dpoName.isNull || !i.dpoEmail.isNull)
      p.appointDpo(i.dpoName.isNull ? p.dpoName : i.dpoName.get, i.dpoEmail.isNull ? p.dpoEmail : i.dpoEmail.get);
    _projects.save(p);
    emit(_events, "ProjectUpdated", p.id, p.id);
    return toDto(p);
  }

  void remove(string id) {
    auto p = load(_projects, id, "Project");
    foreach (x; _activities.byProject(id)) _activities.remove(x.id);
    foreach (x; _requests.byProject(id)) _requests.remove(x.id);
    foreach (x; _breaches.byProject(id)) _breaches.remove(x.id);
    foreach (x; _consents.byProject(id)) _consents.remove(x.id);
    _projects.remove(id);
    emit(_events, "ProjectDeleted", id, id, p.name);
  }
}
