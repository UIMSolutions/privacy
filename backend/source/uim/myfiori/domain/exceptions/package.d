/// Business exceptions of the GDPR domain.
module uim.myfiori.domain.exceptions;

@safe:

/// Base class of all domain errors.
class DomainException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
    super(msg, file, line);
  }
}

/// A business rule or input constraint was violated.
class ValidationException : DomainException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
    super(msg, file, line);
  }
}

/// A referenced aggregate does not exist.
class EntityNotFoundException : DomainException {
  string entityName;
  string id;
  this(string entityName, string id, string file = __FILE__, size_t line = __LINE__) pure nothrow {
    this.entityName = entityName;
    this.id = id;
    super(entityName ~ " '" ~ id ~ "' not found", file, line);
  }
}

/// The operation conflicts with the current state (e.g. archived project).
class ConflictException : DomainException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
    super(msg, file, line);
  }
}
