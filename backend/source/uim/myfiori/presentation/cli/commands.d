/**
 * Command-line interface. Uses the same use cases as OData and the web GUI.
 * Run `gdpr help` for the command reference. Field options are the kebab-case
 * names of the DTO fields (e.g. --legal-basis, --subject-email).
 */
module uim.myfiori.presentation.cli.commands;

@safe:

import std.algorithm : map;
import std.array : array, join;
import std.conv : to;
import std.format : format;
import std.stdio : stderr, stdout;
import vibe.data.json;

import uim.myfiori.appinfo;
import uim.myfiori.application.dtos;
import uim.myfiori.bootstrap;
import uim.myfiori.domain.exceptions;
import uim.myfiori.presentation.cli.args;
import uim.myfiori.presentation.cli.table;
import uim.myfiori.presentation.http.binding;
import uim.myfiori.presentation.http.errors : BadRequestException, classify;
import uim.myfiori.presentation.odata.model : toODataJson;
import uim.myfiori.presentation.web.helpers : daysText, hoursText, label, localTime, percent, shortId;

enum helpText = appName ~ ` ` ~ appVersion ~ ` – ` ~ appTitle ~ ` (GDPR / DSGVO project management)

Usage: gdpr [global options] <command> [arguments] [options]

Server
  serve                                   start HTTP server (OData v4, web GUI, Fiori app)
  gui                                     start server and open the web GUI in a webview window

Projects
  project list
  project show <id>
  project create --name N [--controller C] [--dpo-name D] [--dpo-email E] [--description T]
  project update <id> [--name ..] [--controller ..] [--dpo-name ..] [--dpo-email ..]
                      [--status planned|inProgress|completed|archived]
  project delete <id> --yes

Record of processing activities (Art. 30)
  activity list [--project ID]
  activity create --project ID --name N [--purpose P] [--legal-basis consent|contract|legalObligation|
                  vitalInterests|publicTask|legitimateInterests] [--data-categories ..] [--data-subjects ..]
                  [--recipients ..] [--retention-period ..] [--toms ..] [--special-categories]
                  [--large-scale] [--systematic-monitoring] [--automated-decisions]
                  [--third-country-transfer] [--transfer-safeguard ..] [--dpia-completed]
                  [--status draft|active|retired]
  activity update <id> [same options; booleans as --large-scale=false]
  activity delete <id>

Data subject requests (Art. 15–21, deadline Art. 12 (3))
  request list [--project ID]
  request create --project ID --type access|rectification|erasure|restriction|portability|objection
                 --subject-name N [--subject-email E] [--description D] [--received-on YYYY-MM-DD]
  request update <id> [--status received|verified|inProgress|completed|rejected] [--resolution R]
  request extend <id> --reason R
  request delete <id>

Personal data breaches (Art. 33/34)
  breach list [--project ID]
  breach create --project ID --title T [--severity low|medium|high] [--affected-subjects N]
                [--detected-at ISO] [--description D] [--data-categories ..] [--measures ..]
  breach update <id> [--title ..] [--severity ..] [--affected-subjects ..] [--measures ..]
  breach report <id> [--at ISO]           notification of the supervisory authority
  breach notify <id> [--at ISO]           communication to the data subjects
  breach close <id>
  breach delete <id>

Consents (Art. 7)
  consent list [--project ID] [--email E]
  consent give --project ID --subject-email E --purpose P [--text-version V]
               [--channel web|app|email|paper|phone|other] [--activity ID] [--given-at ISO]
  consent withdraw <id> [--at ISO]
  consent delete <id>

Reporting
  report <projectId>                      compliance score and findings
  deadlines [--notify]                    upcoming / missed deadlines (optionally send alerts)
  version | help

Global options
  --config DIR      configuration directory (default: config, env GDPR_CONFIG_DIR)
  --data FILE       JSON data file           --memory   volatile in-memory storage
  --host H --port P server address           --json     machine readable output
`;

alias ServerRunner = int delegate(DApplicationContainer app, bool openGui) @safe;

class DCommandLine {
  private DApplicationContainer _app;
  private ServerRunner _server;
  private CliArgs _args;

  this(DApplicationContainer app, ServerRunner server) {
    _app = app;
    _server = server;
  }

  /// Executes the command; returns the process exit code.
  int run(CliArgs args) @trusted {
    _args = args;
    auto p = args.positional;
    if (p.length == 0 || p[0] == "help" || args.flag("help")) { stdout.write(helpText); return 0; }
    try {
      switch (p[0]) {
        case "serve": return _server(_app, false);
        case "gui": return _server(_app, true);
        case "version": stdout.writeln(appName, " ", appVersion); return 0;
        case "project": return project(sub);
        case "activity": return activity(sub);
        case "request": return request(sub);
        case "breach": return breach(sub);
        case "consent": return consent(sub);
        case "report": return report(_args.arg(1, "project id"));
        case "deadlines": return deadlines;
        default: throw new BadRequestException("Unknown command '" ~ p[0] ~ "' (see 'gdpr help')");
      }
    } catch (Exception e) {
      auto info = classify(e);
      stderr.writeln("error: ", e.msg);
      return info.code == "InternalError" ? 2 : 1;
    }
  }

  private string sub() { return _args.arg(1, "sub command (see 'gdpr help')"); }
  private string id() { return _args.arg(2, "id"); }

  /// Binds an input DTO from the kebab-case options; `--project` / `--activity` / `--email` map to ids.
  private T opts(T)() {
    auto a = _args;
    return bindStrings!T((string k) {
      if (k == "project-id") k = "project";
      else if (k == "activity-id") k = "activity";
      if (auto v = k in a.options) return *v;
      return null;
    }, &kebab);
  }

  // -------------------------------------------------------------- commands

  private int project(string cmd) @trusted {
    switch (cmd) {
      case "list":
        auto items = _app.projects.list;
        return output(items, ["ID", "Name", "Controller", "DPO", "Status"],
            items.map!(p => [shortId(p.ID), p.name, p.controller, p.dpoName, label(p.status)]).array);
      case "show":
        auto p = _app.projects.get(id);
        return single(p, format("%s (%s)\n  controller: %s\n  DPO: %s %s\n  %s", p.name, label(p.status),
            p.controller, p.dpoName, p.dpoEmail, p.description));
      case "create":
        auto p = _app.projects.create(opts!CreateProjectInput);
        return single(p, "Project created: " ~ p.ID);
      case "update":
        auto p = _app.projects.update(resolve("project", id), opts!UpdateProjectInput);
        return single(p, "Project updated: " ~ p.ID);
      case "delete":
        if (!_args.flag("yes")) throw new BadRequestException("Deleting a project removes all registers; add --yes");
        _app.projects.remove(resolve("project", id));
        stdout.writeln("Project deleted");
        return 0;
      default: return unknown(cmd);
    }
  }

  private int activity(string cmd) @trusted {
    switch (cmd) {
      case "list":
        auto items = _app.activities.list(projectOpt);
        return output(items, ["ID", "Name", "Legal basis", "Risk", "DPIA", "Status"], items.map!(a => [shortId(a.ID),
            a.name, label(a.legalBasis), label(a.riskLevel),
            a.dpiaRequired ? (a.dpiaCompleted ? "done" : "REQUIRED") : "-", label(a.status)]).array);
      case "create":
        auto i = opts!CreateActivityInput;
        i.projectId = resolve("project", i.projectId);
        auto a = _app.activities.create(i);
        return single(a, format("Activity created: %s (risk %s%s)", a.ID, a.riskLevel, a.dpiaRequired ? ", DPIA required" : ""));
      case "update":
        auto a = _app.activities.update(resolve("activity", id), opts!UpdateActivityInput);
        return single(a, "Activity updated: " ~ a.ID ~ " (" ~ a.status ~ ")");
      case "delete":
        _app.activities.remove(resolve("activity", id));
        stdout.writeln("Activity deleted");
        return 0;
      default: return unknown(cmd);
    }
  }

  private int request(string cmd) @trusted {
    switch (cmd) {
      case "list":
        auto items = _app.requests.list(projectOpt);
        return output(items, ["ID", "Right", "Data subject", "Received", "Due", "Remaining", "Status"],
            items.map!(r => [shortId(r.ID), label(r.type) ~ " (" ~ r.article ~ ")", r.subjectName, r.receivedOn,
              r.dueDate, (r.status == "completed" || r.status == "rejected") ? "-" : daysText(r.daysLeft),
              label(r.status)]).array);
      case "create":
        auto i = opts!CreateRequestInput;
        i.projectId = resolve("project", i.projectId);
        auto r = _app.requests.create(i);
        return single(r, "Request recorded: " ~ r.ID ~ ", due " ~ r.dueDate);
      case "update":
        auto r = _app.requests.update(resolve("request", id), opts!UpdateRequestInput);
        return single(r, "Request updated: " ~ label(r.status));
      case "extend":
        auto r = _app.requests.extend(resolve("request", id), _args.required("reason"));
        return single(r, "Deadline extended to " ~ r.dueDate);
      case "delete":
        _app.requests.remove(resolve("request", id));
        stdout.writeln("Request deleted");
        return 0;
      default: return unknown(cmd);
    }
  }

  private int breach(string cmd) @trusted {
    switch (cmd) {
      case "list":
        auto items = _app.breaches.list(projectOpt);
        return output(items, ["ID", "Title", "Detected", "Risk", "Authority", "Subjects", "Status"],
            items.map!(b => [shortId(b.ID), b.title, localTime(b.detectedAt), label(b.severity),
              !b.authorityNotificationRequired ? "-" : b.reportedAt.length ? "reported" : hoursText(b.hoursLeft),
              !b.subjectNotificationRequired ? "-" : b.subjectsNotifiedAt.length ? "notified" : "PENDING",
              label(b.status)]).array);
      case "create":
        auto i = opts!CreateBreachInput;
        i.projectId = resolve("project", i.projectId);
        auto b = _app.breaches.create(i);
        return single(b, b.authorityNotificationRequired
            ? "Breach recorded: " ~ b.ID ~ " – notify the authority by " ~ b.notificationDeadline
            : "Breach recorded: " ~ b.ID ~ " – no notification required, keep it documented");
      case "update":
        auto b = _app.breaches.update(resolve("breach", id), opts!UpdateBreachInput);
        return single(b, "Breach updated");
      case "report":
        auto b = _app.breaches.reportToAuthority(resolve("breach", id), _args.opt("at"));
        return single(b, b.deadlineMissed ? "Reported (late – document the reasons, Art. 33 (1))" : "Reported in time");
      case "notify":
        auto b = _app.breaches.notifySubjects(resolve("breach", id), _args.opt("at"));
        return single(b, "Data subjects notified");
      case "close":
        auto b = _app.breaches.close(resolve("breach", id));
        return single(b, "Breach closed");
      case "delete":
        _app.breaches.remove(resolve("breach", id));
        stdout.writeln("Breach deleted");
        return 0;
      default: return unknown(cmd);
    }
  }

  private int consent(string cmd) @trusted {
    switch (cmd) {
      case "list":
        auto items = _app.consents.list(projectOpt, _args.opt("email"));
        return output(items, ["ID", "Data subject", "Purpose", "Version", "Given", "Status"],
            items.map!(c => [shortId(c.ID), c.subjectEmail, c.purpose, c.textVersion, localTime(c.givenAt),
              c.active ? "active" : "withdrawn " ~ localTime(c.withdrawnAt)]).array);
      case "give":
        auto i = opts!CreateConsentInput;
        i.projectId = resolve("project", i.projectId);
        if (i.activityId.length) i.activityId = resolve("activity", i.activityId);
        auto c = _app.consents.give(i);
        return single(c, "Consent recorded: " ~ c.ID);
      case "withdraw":
        auto c = _app.consents.withdraw(resolve("consent", id), _args.opt("at"));
        return single(c, "Consent withdrawn");
      case "delete":
        _app.consents.remove(resolve("consent", id));
        stdout.writeln("Consent deleted");
        return 0;
      default: return unknown(cmd);
    }
  }

  private int report(string projectId) @trusted {
    auto r = _app.reports.projectReport(resolve("project", projectId));
    if (_args.flag("json")) { stdout.writeln(toODataJson(r).toPrettyString); return 0; }
    stdout.writefln("%s – compliance %s", r.projectName, percent(r.complianceScore));
    stdout.writefln("  activities %d (active %d, high risk %d, DPIA open %d, transfers w/o safeguard %d)",
        r.activitiesTotal, r.activitiesActive, r.activitiesHighRisk, r.dpiaOpen, r.transfersWithoutSafeguard);
    stdout.writefln("  requests   %d (open %d, overdue %d)", r.requestsTotal, r.requestsOpen, r.requestsOverdue);
    stdout.writefln("  breaches   %d (open %d, unreported %d, late %d)", r.breachesTotal, r.breachesOpen,
        r.breachesNotReported, r.breachesDeadlineMissed);
    stdout.writefln("  consents   %d (active %d, withdrawn %d)", r.consentsTotal, r.consentsActive, r.consentsWithdrawn);
    if (r.findings.length) {
      stdout.writeln("\nFindings");
      stdout.write(renderTable(["Severity", "Article", "Finding"],
          r.findings.map!(f => [f.severity, f.article, f.text]).array, 100));
    }
    return 0;
  }

  private int deadlines() @trusted {
    auto alerts = _app.deadlines.alerts;
    if (_args.flag("notify")) {
      auto n = _app.deadlines.notifyResponsibles;
      stderr.writefln("%d alert(s) sent via %s", n, _app.notifications.describe);
    }
    return output(alerts, ["Kind", "Project", "Item", "Deadline", "Remaining"], alerts.map!(a => [a.kind, a.projectName,
        a.title, a.kind == "breach" ? localTime(a.deadline) : a.deadline,
        a.kind == "breach" ? hoursText(a.remaining) : daysText(a.remaining)]).array);
  }

  // -------------------------------------------------------------- helpers

  private string projectOpt() { auto p = _args.opt("project"); return p.length ? resolve("project", p) : ""; }

  /// Accepts full ids and unique prefixes (as printed by the list commands).
  private string resolve(string kind, string idOrPrefix) {
    if (idOrPrefix.length == 0) throw new BadRequestException("--" ~ kind ~ " is required");
    string[] ids;
    switch (kind) {
      case "project": ids = _app.projects.list.map!(x => x.ID).array; break;
      case "activity": ids = _app.activities.list.map!(x => x.ID).array; break;
      case "request": ids = _app.requests.list.map!(x => x.ID).array; break;
      case "breach": ids = _app.breaches.list.map!(x => x.ID).array; break;
      default: ids = _app.consents.list.map!(x => x.ID).array; break;
    }
    string[] hits;
    foreach (i; ids) {
      if (i == idOrPrefix) return i;
      if (i.length > idOrPrefix.length && i[0 .. idOrPrefix.length] == idOrPrefix) hits ~= i;
    }
    if (hits.length == 1) return hits[0];
    if (hits.length > 1) throw new BadRequestException("Ambiguous " ~ kind ~ " id '" ~ idOrPrefix ~ "'");
    throw new EntityNotFoundException(kind, idOrPrefix);
  }

  private int output(T)(T[] items, string[] header, string[][] rows) @trusted {
    if (_args.flag("json")) {
      auto j = Json.emptyArray;
      foreach (i; items) j ~= toODataJson(i);
      stdout.writeln(j.toPrettyString);
    } else if (rows.length == 0) {
      stdout.writeln("(none)");
    } else {
      stdout.write(renderTable(header, rows));
    }
    return 0;
  }

  private int single(T)(T item, string text) @trusted {
    if (_args.flag("json")) stdout.writeln(toODataJson(item).toPrettyString);
    else stdout.writeln(text);
    return 0;
  }

  private static int unknown(string cmd) {
    throw new BadRequestException("Unknown sub command '" ~ cmd ~ "' (see 'gdpr help')");
  }
}
