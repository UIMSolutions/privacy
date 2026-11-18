/// Driving ports for application-wide services.
module uim.myfiori.ports.services;

@safe:

import uim.myfiori.application.dtos;

/// Deadline monitoring across all projects (DSR response deadlines, 72 h breach notification).
interface IDeadlineService {
  /// Current alerts, most urgent first.
  DeadlineAlertDto[] alerts();
  /// Sends all current alerts to the DPO of each project; returns the number sent.
  size_t notifyResponsibles();
}
