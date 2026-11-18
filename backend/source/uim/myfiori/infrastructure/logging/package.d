/// Technical logging and the audit trail for domain events (accountability, Art. 5 (2) GDPR).
module uim.myfiori.infrastructure.logging;

@safe:

import vibe.core.log;
import uim.myfiori.ports.messaging;

/// Applies the configured log level ("trace", "debug", "info", "warn", "error").
void configureLogging(string level) @trusted {
  switch (level) {
    case "trace": setLogLevel(LogLevel.trace); break;
    case "debug": setLogLevel(LogLevel.debug_); break;
    case "warn": setLogLevel(LogLevel.warn); break;
    case "error": setLogLevel(LogLevel.error); break;
    default: setLogLevel(LogLevel.info); break;
  }
}

/**
 * Event publisher writing every domain event to the log (audit trail) and keeping
 * the most recent events in memory for the web GUI activity feed. Events never
 * contain personal data beyond identifiers (data minimisation, Art. 5 (1) c).
 */
class DAuditLogPublisher : IDomainEventPublisher {
  private DomainEvent[] _recent;
  private size_t _capacity;

  this(size_t capacity = 100) { _capacity = capacity; }

  void publish(DomainEvent e) {
    logInfo("[audit] %s %s project=%s %s", e.type, e.aggregateId, e.projectId, e.details);
    _recent = e ~ _recent;
    if (_recent.length > _capacity) _recent = _recent[0 .. _capacity];
  }

  /// Most recent first, optionally restricted to one project.
  const(DomainEvent)[] recent(size_t max = 20, string projectId = "") const {
    const(DomainEvent)[] r;
    foreach (ref e; _recent) {
      if (projectId.length && e.projectId != projectId) continue;
      r ~= e;
      if (r.length >= max) break;
    }
    return r;
  }
}
