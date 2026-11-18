/// Shared helpers of the use cases.
module uim.myfiori.application.usecases.common;

@safe:

import std.algorithm : sort;
import std.array : array;
import uim.myfiori.domain;
import uim.myfiori.ports.repositories;

/// Loads an aggregate or throws EntityNotFoundException.
T load(T)(IRepository!T repo, string id, string entityName) {
  auto e = repo.find(id);
  if (e is null) throw new EntityNotFoundException(entityName, id);
  return e;
}

/// Loads the project and ensures it may be changed (not archived).
DProject writableProject(IProjectRepository projects, string projectId) {
  if (projectId.length == 0) throw new ValidationException("projectId is required");
  auto p = load(projects, projectId, "Project");
  p.ensureWritable;
  return p;
}

/// All aggregates of a project, or of all projects when projectId is empty.
T[] scoped(T)(IProjectScopedRepository!T repo, IProjectRepository projects, string projectId) {
  if (projectId.length == 0) return repo.all;
  load(projects, projectId, "Project");
  return repo.byProject(projectId);
}

/// Sort helper: newest first by creation time.
T[] newestFirst(T)(T[] items) {
  return items.sort!((a, b) => a.createdAt > b.createdAt).array;
}
