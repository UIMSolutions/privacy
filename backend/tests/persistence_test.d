/// JSON file storage round trip of all aggregates.
module persistence_test;

version (GdprUnittest):

import std.file : exists, remove, tempDir;
import std.path : buildPath;
import uim.myfiori.application.dtos;
import uim.myfiori.bootstrap;
import uim.myfiori.infrastructure.configuration : AppConfig;
import uim.myfiori.persistence.storages : DJsonFileDocumentStorage;

unittest {
  auto file = buildPath(tempDir, "gdpr-persistence-test.json");
  if (file.exists) remove(file);
  scope (exit) if (file.exists) remove(file);
  AppConfig cfg;
  string projectId, consentId;
  {
    auto a = new DApplicationContainer(cfg, new DJsonFileDocumentStorage(file));
    auto p = a.projects.create(CreateProjectInput("Persisted", "d", "ACME", "Erika", "dpo@acme.example"));
    projectId = p.ID;
    a.activities.create(CreateActivityInput(p.ID, "Newsletter", "marketing", "consent"));
    a.requests.create(CreateRequestInput(p.ID, "access", "Max", "max@x.example", "", "2026-01-10"));
    CreateBreachInput b = { projectId: p.ID, title: "Phishing", detectedAt: "2026-01-02T10:00:00Z", severity: "medium" };
    a.breaches.reportToAuthority(a.breaches.create(b).ID, "2026-01-03T09:00:00Z");
    CreateConsentInput c = { projectId: p.ID, subjectEmail: "a@b.example", purpose: "News", textVersion: "v2" };
    consentId = a.consents.give(c).ID;
    a.consents.withdraw(consentId);
  }
  auto a = new DApplicationContainer(cfg, new DJsonFileDocumentStorage(file));
  assert(a.projects.get(projectId).dpoEmail == "dpo@acme.example");
  assert(a.activities.list(projectId)[0].legalBasis == "consent");
  assert(a.requests.list(projectId)[0].dueDate == "2026-02-10");
  auto br = a.breaches.list(projectId)[0];
  assert(br.status == "reported" && br.reportedAt == "2026-01-03T09:00:00Z" && !br.deadlineMissed);
  auto c = a.consents.get(consentId);
  assert(!c.active && c.textVersion == "v2");
}
