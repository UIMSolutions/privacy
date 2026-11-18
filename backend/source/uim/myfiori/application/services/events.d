/// Helper for publishing domain events from use cases.
module uim.myfiori.application.services.events;

@safe:

import uim.myfiori.domain.types : isoTimestamp, now;
import uim.myfiori.ports.messaging;

void emit(IDomainEventPublisher publisher, string type, string aggregateId, string projectId, string details = "") {
  if (publisher is null) return;
  publisher.publish(DomainEvent(type, aggregateId, projectId, details, isoTimestamp(now)));
}
