/// Driving ports: the use cases offered to all presentation adapters (OData, web, CLI).
module uim.myfiori.ports.usecases;

@safe:

import uim.myfiori.application.dtos;

interface IProjectUseCases {
  ProjectDto[] list();
  ProjectDto get(string id);
  ProjectDto create(CreateProjectInput input);
  ProjectDto update(string id, UpdateProjectInput input);
  /// Deletes the project together with all its registers.
  void remove(string id);
}

/// Record of processing activities (Art. 30).
interface IProcessingActivityUseCases {
  ProcessingActivityDto[] list(string projectId = "");
  ProcessingActivityDto get(string id);
  ProcessingActivityDto create(CreateActivityInput input);
  ProcessingActivityDto update(string id, UpdateActivityInput input);
  void remove(string id);
}

/// Data subject requests (Art. 15–21).
interface IDataSubjectRequestUseCases {
  DataSubjectRequestDto[] list(string projectId = "");
  DataSubjectRequestDto get(string id);
  DataSubjectRequestDto create(CreateRequestInput input);
  DataSubjectRequestDto update(string id, UpdateRequestInput input);
  /// Extends the response deadline (Art. 12 (3) sentence 2).
  DataSubjectRequestDto extend(string id, string reason);
  void remove(string id);
}

/// Personal data breaches (Art. 33/34).
interface IDataBreachUseCases {
  DataBreachDto[] list(string projectId = "");
  DataBreachDto get(string id);
  DataBreachDto create(CreateBreachInput input);
  DataBreachDto update(string id, UpdateBreachInput input);
  /// Records the notification of the supervisory authority; `at` empty = now.
  DataBreachDto reportToAuthority(string id, string at = "");
  /// Records the communication to the data subjects; `at` empty = now.
  DataBreachDto notifySubjects(string id, string at = "");
  DataBreachDto close(string id);
  void remove(string id);
}

/// Consent register (Art. 7).
interface IConsentUseCases {
  ConsentDto[] list(string projectId = "", string subjectEmail = "");
  ConsentDto get(string id);
  ConsentDto give(CreateConsentInput input);
  ConsentDto update(string id, UpdateConsentInput input);
  ConsentDto withdraw(string id, string at = "");
  void remove(string id);
}

/// Compliance reporting.
interface IReportUseCases {
  ProjectReportDto projectReport(string projectId);
}
