/**
 * Composition root: wires adapters to ports. The only module that knows
 * all concrete implementations.
 */
module uim.myfiori.bootstrap;

@safe:

import uim.myfiori.application;
import uim.myfiori.infrastructure;
import uim.myfiori.persistence;
import uim.myfiori.ports;

class DApplicationContainer {
  AppConfig config;
  IDocumentStorage storage;
  DAuditLogPublisher audit;
  INotificationGateway notifications;
  DAuthGuard authGuard;

  IProjectUseCases projects;
  IProcessingActivityUseCases activities;
  IDataSubjectRequestUseCases requests;
  IDataBreachUseCases breaches;
  IConsentUseCases consents;
  IReportUseCases reports;
  IDeadlineService deadlines;

  this(AppConfig config) {
    this(config, config.storage == "memory"
        ? new DMemoryDocumentStorage
        : new DJsonFileDocumentStorage(config.dataFile));
  }

  this(AppConfig config, IDocumentStorage storage, INotificationGateway notifications = null) {
    this.config = config;
    this.storage = storage;
    audit = new DAuditLogPublisher;
    authGuard = new DAuthGuard(config);
    if (notifications !is null) this.notifications = notifications;
    else if (config.alertWebhook.length) this.notifications = new DWebhookNotificationClient(config.alertWebhook);
    else this.notifications = new DLogNotificationClient;

    auto projectRepo = new DProjectRepository(storage, Collections.projects);
    auto activityRepo = new DProcessingActivityRepository(storage, Collections.activities);
    auto requestRepo = new DDataSubjectRequestRepository(storage, Collections.requests);
    auto breachRepo = new DDataBreachRepository(storage, Collections.breaches);
    auto consentRepo = new DConsentRepository(storage, Collections.consents);
    auto policy = config.policy;

    projects = new DProjectUseCases(projectRepo, activityRepo, requestRepo, breachRepo, consentRepo, audit);
    activities = new DProcessingActivityUseCases(projectRepo, activityRepo, consentRepo, audit);
    requests = new DDataSubjectRequestUseCases(projectRepo, requestRepo, audit, policy);
    breaches = new DDataBreachUseCases(projectRepo, breachRepo, audit, policy);
    consents = new DConsentUseCases(projectRepo, activityRepo, consentRepo, audit);
    reports = new DReportUseCases(projectRepo, activityRepo, requestRepo, breachRepo, consentRepo, policy);
    deadlines = new DDeadlineService(projectRepo, requestRepo, breachRepo, this.notifications, policy,
        config.deadlineWarnDays);
  }

  /// Volatile container for tests.
  static DApplicationContainer inMemory(INotificationGateway notifications = null) {
    AppConfig cfg;
    cfg.storage = "memory";
    return new DApplicationContainer(cfg, new DMemoryDocumentStorage, notifications);
  }
}
