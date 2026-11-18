/// End-to-end use case scenarios on the in-memory container.
module usecases_test;

version (GdprUnittest):

import std.algorithm : canFind, map;
import std.array : array;
import std.exception : assertThrown;
import std.typecons : Nullable;
import uim.myfiori.application.dtos;
import uim.myfiori.bootstrap;
import uim.myfiori.domain.exceptions;
import uim.myfiori.infrastructure.clients : DLogNotificationClient;

private DApplicationContainer app() { return DApplicationContainer.inMemory; }

unittest { // project life cycle and archive protection
  auto a = app;
  auto p = a.projects.create(CreateProjectInput("GDPR 2026", "", "ACME GmbH", "Erika DPO", "dpo@acme.example"));
  assert(a.projects.list.length == 1 && p.status == "planned");
  UpdateProjectInput u;
  u.status = "archived";
  a.projects.update(p.ID, u);
  CreateRequestInput r = { projectId: p.ID, type: "access", subjectName: "Max" };
  assertThrown!ConflictException(a.requests.create(r));
  u.status = "inProgress";
  a.projects.update(p.ID, u);
  a.requests.create(r);
  a.projects.remove(p.ID);
  assert(a.requests.list.length == 0);
}

unittest { // record of processing: activation rules and DPIA
  auto a = app;
  auto p = a.projects.create(CreateProjectInput("P", "", "", "", ""));
  CreateActivityInput i = { projectId: p.ID, name: "HR files", purpose: "Personnel administration",
    legalBasis: "contract", specialCategories: true, largeScale: true, status: "active" };
  assertThrown!ValidationException(a.activities.create(i));   // incomplete record
  i.status = "draft";
  auto act = a.activities.create(i);
  assert(act.dpiaRequired && act.riskLevel == "high");
  UpdateActivityInput u;
  u.dataCategories = "master data, health data";
  u.dataSubjects = "employees";
  u.retentionPeriod = "10 years after termination";
  u.status = "active";
  assertThrown!ValidationException(a.activities.update(act.ID, u));   // DPIA missing
  u.dpiaCompleted = true;
  assert(a.activities.update(act.ID, u).status == "active");
  auto rep = a.reports.projectReport(p.ID);
  assert(rep.dpiaOpen == 0 && rep.activitiesActive == 1);
  assert(rep.findings.map!(f => f.article).array.canFind("Art. 37"));   // no DPO
}

unittest { // data subject request: deadline, extension, closing
  auto a = app;
  auto p = a.projects.create(CreateProjectInput("P", "", "", "", "dpo@x.example"));
  CreateRequestInput i = { projectId: p.ID, type: "erasure", subjectName: "Max", subjectEmail: "max@x.example",
    receivedOn: "2025-01-31" };
  auto r = a.requests.create(i);
  assert(r.dueDate == "2025-02-28" && r.overdue && r.article == "Art. 17");
  assert(a.reports.projectReport(p.ID).requestsOverdue == 1);
  assert(a.requests.extend(r.ID, "many systems").dueDate == "2025-04-30");
  assertThrown!ConflictException(a.requests.extend(r.ID, "again"));
  UpdateRequestInput u;
  u.status = "completed";
  assertThrown!ValidationException(a.requests.update(r.ID, u));
  u.resolution = "data erased in CRM and backup rotation";
  auto done = a.requests.update(r.ID, u);
  assert(done.status == "completed" && !done.overdue && done.closedOn.length);
  assertThrown!ValidationException(a.requests.create(CreateRequestInput(p.ID, "delete", "x")));
}

unittest { // breach: 72 h deadline, notifications, alerts
  auto notifier = new DLogNotificationClient;
  auto a = DApplicationContainer.inMemory(notifier);
  auto p = a.projects.create(CreateProjectInput("P", "", "", "", "dpo@x.example"));
  CreateBreachInput i = { projectId: p.ID, title: "Mail to wrong recipient", detectedAt: "2025-01-01T08:00:00Z",
    severity: "high", affectedSubjects: 3 };
  auto b = a.breaches.create(i);
  assert(b.notificationDeadline == "2025-01-04T08:00:00Z" && b.deadlineMissed);
  assert(a.deadlines.alerts.length == 1 && a.deadlines.notifyResponsibles == 1 && notifier.sent == 1);
  assertThrown!ValidationException(a.breaches.close(b.ID));
  a.breaches.reportToAuthority(b.ID);
  assertThrown!ConflictException(a.breaches.remove(b.ID));   // reported breaches stay documented
  a.breaches.notifySubjects(b.ID);
  UpdateBreachInput u;
  u.measures = "recall requested, staff instructed";
  a.breaches.update(b.ID, u);
  assert(a.breaches.close(b.ID).status == "closed");
  assert(a.deadlines.alerts.length == 0);
  auto rep = a.reports.projectReport(p.ID);
  assert(rep.breachesDeadlineMissed == 1 && rep.breachesNotReported == 0);

  CreateBreachInput low = { projectId: p.ID, title: "Encrypted USB stick lost", severity: "low" };
  auto l = a.breaches.create(low);
  assert(!l.authorityNotificationRequired && !l.deadlineMissed);
  a.breaches.remove(l.ID);   // open, unreported → may be deleted
}

unittest { // consents: activity check and withdrawal
  auto a = app;
  auto p = a.projects.create(CreateProjectInput("P", "", "", "", ""));
  auto contract = a.activities.create(CreateActivityInput(p.ID, "Orders", "fulfilment", "contract"));
  auto news = a.activities.create(CreateActivityInput(p.ID, "Newsletter", "marketing", "consent"));
  CreateConsentInput c = { projectId: p.ID, activityId: contract.ID, subjectEmail: "a@b.example", purpose: "Newsletter" };
  assertThrown!ValidationException(a.consents.give(c));
  c.activityId = news.ID;
  auto given = a.consents.give(c);
  assert(given.active && given.channel == "web");
  assertThrown!ConflictException(a.activities.remove(news.ID));
  assert(a.consents.list(p.ID, "A@B.example").length == 1);
  assert(!a.consents.withdraw(given.ID).active);
  assertThrown!ConflictException(a.consents.withdraw(given.ID));
  assert(a.reports.projectReport(p.ID).consentsWithdrawn == 1);
}
