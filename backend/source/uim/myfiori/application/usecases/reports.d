module uim.myfiori.application.usecases.reports;

@safe:

import std.algorithm : any, count, filter, map;
import std.array : array;
import uim.myfiori.application.dtos;
import uim.myfiori.application.usecases.common;
import uim.myfiori.domain;
import uim.myfiori.ports;

class DReportUseCases : IReportUseCases {
  private IProjectRepository _projects;
  private IProcessingActivityRepository _activities;
  private IDataSubjectRequestRepository _requests;
  private IDataBreachRepository _breaches;
  private IConsentRepository _consents;
  private DeadlinePolicy _policy;

  this(IProjectRepository projects, IProcessingActivityRepository activities, IDataSubjectRequestRepository requests,
      IDataBreachRepository breaches, IConsentRepository consents, DeadlinePolicy policy) {
    _projects = projects;
    _activities = activities;
    _requests = requests;
    _breaches = breaches;
    _consents = consents;
    _policy = policy;
  }

  ProjectReportDto projectReport(string projectId) {
    auto project = load(_projects, projectId, "Project");
    auto activities = _activities.byProject(projectId);
    auto requests = _requests.byProject(projectId);
    auto breaches = _breaches.byProject(projectId);
    auto consents = _consents.byProject(projectId);
    auto day = today;
    auto at = now;
    auto p = _policy;

    ProjectReportDto r;
    r.projectId = project.id;
    r.projectName = project.name;
    import std.conv : to;
    r.status = project.status.to!string;

    // retired activities are no longer processed and do not count as gaps
    auto current = activities.filter!(a => a.status != ActivityStatus.retired).array;
    r.activitiesTotal = cast(int) activities.length;
    r.activitiesActive = cast(int) current.count!(a => a.status == ActivityStatus.active);
    r.activitiesHighRisk = cast(int) current.count!(a => a.riskLevel == RiskLevel.high);
    r.dpiaRequired = cast(int) current.count!(a => a.dpiaRequired);
    r.dpiaOpen = cast(int) current.count!(a => a.dpiaRequired && !a.dpiaCompleted);
    r.transfersWithoutSafeguard = cast(int) current.count!(a => a.transferWithoutSafeguard);

    r.requestsTotal = cast(int) requests.length;
    r.requestsOpen = cast(int) requests.count!(q => !q.closed);
    r.requestsOverdue = cast(int) requests.count!(q => q.overdue(p, day));

    r.breachesTotal = cast(int) breaches.length;
    r.breachesOpen = cast(int) breaches.count!(b => b.status != BreachStatus.closed);
    r.breachesNotReported = cast(int) breaches.count!(b => b.authorityNotificationRequired && b.reportedAt.isNull);
    r.breachesDeadlineMissed = cast(int) breaches.count!(b => b.deadlineMissed(p, at));

    r.consentsTotal = cast(int) consents.length;
    r.consentsActive = cast(int) consents.count!(c => c.active);
    r.consentsWithdrawn = r.consentsTotal - r.consentsActive;

    ComplianceFigures f;
    f.activities = cast(int) current.length;
    f.activitiesActive = r.activitiesActive;
    f.activitiesDraft = cast(int) current.count!(a => a.status == ActivityStatus.draft);
    f.dpiaRequired = r.dpiaRequired;
    f.dpiaOpen = r.dpiaOpen;
    f.transfersWithoutSafeguard = r.transfersWithoutSafeguard;
    f.requestsOpen = r.requestsOpen;
    f.requestsOverdue = r.requestsOverdue;
    f.breachesOpen = r.breachesOpen;
    f.breachesDeadlineMissed = r.breachesDeadlineMissed;
    f.breachesNotReported = r.breachesNotReported;
    f.breachesSubjectsPending = cast(int) breaches.count!(b => b.subjectNotificationRequired && b.subjectsNotifiedAt.isNull);
    f.consentActivitiesWithoutConsents = cast(int) current
      .filter!(a => a.legalBasis == LegalBasis.consent && a.status == ActivityStatus.active)
      .count!(a => !consents.any!(c => c.activityId == a.id));
    f.dpoAppointed = project.dpoName.length > 0 || project.dpoEmail.length > 0;

    auto findings = assessCompliance(f);
    r.findings = findings.map!(x => FindingDto(x.severity, x.article, x.text)).array;
    r.complianceScore = complianceScore(findings);
    return r;
  }
}
