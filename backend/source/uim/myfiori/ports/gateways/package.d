/// Driven ports for external systems (alerting / notification channels).
module uim.myfiori.ports.gateways;

@safe:

/// Outbound notification channel, e.g. e-mail relay or chat webhook for DPO alerts.
interface INotificationGateway {
  /// Sends a notification; implementations must not throw on delivery failures (they log instead).
  void send(string recipient, string subject, string message);
  string describe();
}
