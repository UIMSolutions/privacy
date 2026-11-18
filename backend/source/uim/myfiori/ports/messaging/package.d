/// Driven ports for domain events (audit trail, messaging integration).
module uim.myfiori.ports.messaging;

@safe:

struct DomainEvent {
  string type;          // e.g. "ProjectCreated"
  string aggregateId;
  string projectId;
  string details;
  string occurredAt;    // ISO timestamp
}

interface IDomainEventPublisher {
  void publish(DomainEvent event);
}
