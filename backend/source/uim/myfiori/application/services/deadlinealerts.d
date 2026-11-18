/// Deadline monitoring service (used by the background worker, the web dashboard and the CLI).
module uim.myfiori.application.services.deadlinealerts;

@safe:

import std.algorithm : sort;
import std.array : array;
import std.conv : to;
import std.format : format;
import uim.myfiori.application.dtos;
import uim.myfiori.domain;
import uim.myfiori.ports;

class DDeadlineService : IDeadlineService {
  private IProjectRepository _projects;
  private IDataSubjectRequestRepository _requests;
  private IDataBreachRepository _breaches;
  private INotificationGateway _notifications;
  private DeadlinePolicy _policy;
  private int _warnDays;

  /// `warnDays`: requests are reported when due within this many days.
  this(IProjectRepository projects, IDataSubjectRequestRepository requests, IDataBreachRepository breaches,
      INotificationGateway notifications, DeadlinePolicy policy, int warnDays = 7) {
    _projects = projects;
    _requests = requests;
    _breaches = breaches;
    _notifications = notifications;
    _policy = policy;
    _warnDays = warnDays;
  }

  DeadlineAlertDto[] alerts() {
    auto day = today;
    auto at = now;
    DeadlineAlertDto[] r;
    foreach (project; _projects.all) {
      if (project.archived) continue;
      foreach (q; _requests.byProject(project.id)) {
        if (q.closed) continue;
        auto left = q.daysLeft(_policy, day);
        if (left > _warnDays) continue;
        r ~= DeadlineAlertDto("request", q.id, project.id, project.name, project.dpoEmail,
            format("%s request (%s) of %s", q.type.to!string, article(q.type), q.subjectName),
            q.dueDate(_policy).toISOExtString, left < 0, left);
      }
      foreach (b; _breaches.byProject(project.id)) {
        if (!b.authorityNotificationRequired || !b.reportedAt.isNull || b.status == BreachStatus.closed) continue;
        r ~= DeadlineAlertDto("breach", b.id, project.id, project.name, project.dpoEmail,
            "Breach '" ~ b.title ~ "' not yet notified to the supervisory authority (Art. 33)",
            isoTimestamp(b.notificationDeadline(_policy)), b.deadlineMissed(_policy, at), b.hoursLeft(_policy, at));
      }
    }
    // missed first, then breaches (hours) before requests (days), then by remaining time
    return r.sort!((a, b) => a.missed != b.missed ? a.missed
        : a.kind != b.kind ? a.kind == "breach" : a.remaining < b.remaining).array;
  }

  size_t notifyResponsibles() {
    size_t n;
    foreach (a; alerts) {
      auto unit = a.kind == "breach" ? "hours" : "days";
      auto msg = a.missed
        ? format("DEADLINE MISSED: %s (deadline %s, %d %s ago)", a.title, a.deadline, -a.remaining, unit)
        : format("%s – deadline %s (%d %s left)", a.title, a.deadline, a.remaining, unit);
      _notifications.send(a.recipient.length ? a.recipient : "dpo", "[GDPR] " ~ a.projectName, msg);
      n++;
    }
    return n;
  }
}
