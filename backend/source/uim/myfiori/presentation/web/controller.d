/**
 * Server-side rendered web GUI (Diet templates + BeerCSS + htmx). Also the content
 * of the desktop webview (see presentation/gui).
 *
 * Pages are full documents; the project tabs are HTML fragments loaded and replaced
 * by htmx (`#panel`). Every writing request (htmx POST) must carry the per-user
 * CSRF token in the `X-CSRF-Token` header (set globally via `hx-headers`).
 * Errors of htmx requests are returned as plain text with status 4xx/5xx and
 * shown in a snackbar; successful writes send an `HX-Trigger: notify` event.
 */
module uim.myfiori.presentation.web.controller;

@safe:

import std.algorithm : filter, map;
import std.array : array;
import std.conv : to;
import std.digest : toHexString;
import std.digest.hmac : hmac;
import std.digest.sha : SHA256;
import std.string : representation;
import vibe.core.log;
import vibe.data.json : Json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.textfilter.urlencode : urlEncode;

import uim.myfiori.appinfo;
import uim.myfiori.application.dtos;
import uim.myfiori.bootstrap;
import uim.myfiori.infrastructure.security : Principal, requiredScope;
import uim.myfiori.presentation.http.auth;
import uim.myfiori.presentation.http.binding;
import uim.myfiori.presentation.http.errors;
import uim.myfiori.presentation.web.helpers;



class DWebController {
  private DApplicationContainer _app;
  private ubyte[] _csrfSecret;

  this(DApplicationContainer app) {
    import std.random : uniform;
    _app = app;
    foreach (i; 0 .. 32) _csrfSecret ~= cast(ubyte) uniform(0, 256);
  }

  void register(URLRouter r) {
    r.get("/", (HTTPServerRequest req, HTTPServerResponse res) @safe { res.redirect("/web"); });
    r.get("/web", &guarded!index);
    r.get("/web/deadlines", &guarded!deadlines);
    r.post("/web/projects", &guarded!createProject);
    r.get("/web/projects/:id", &guarded!projectPage);
    r.get("/web/projects/:id/panel/:tab", &guarded!panel);
    r.post("/web/projects/:id", &guarded!updateProject);
    r.post("/web/projects/:id/delete", &guarded!deleteProject);
    // record of processing activities
    r.post("/web/projects/:id/activities", &guarded!createActivity);
    r.post("/web/activities/:id", &guarded!updateActivity);
    r.post("/web/activities/:id/delete", &guarded!deleteActivity);
    // data subject requests
    r.post("/web/projects/:id/requests", &guarded!createRequest);
    r.post("/web/requests/:id", &guarded!updateRequest);
    r.post("/web/requests/:id/extend", &guarded!extendRequest);
    r.post("/web/requests/:id/delete", &guarded!deleteRequest);
    // breaches
    r.post("/web/projects/:id/breaches", &guarded!createBreach);
    r.post("/web/breaches/:id", &guarded!updateBreach);
    r.post("/web/breaches/:id/report", &guarded!reportBreach);
    r.post("/web/breaches/:id/notify", &guarded!notifyBreach);
    r.post("/web/breaches/:id/close", &guarded!closeBreach);
    r.post("/web/breaches/:id/delete", &guarded!deleteBreach);
    // consents
    r.post("/web/projects/:id/consents", &guarded!createConsent);
    r.post("/web/consents/:id/withdraw", &guarded!withdrawConsent);
    r.post("/web/consents/:id/delete", &guarded!deleteConsent);
  }

  // -------------------------------------------------------------- pages

  private void index(HTTPServerRequest req, HTTPServerResponse res, Principal user) @trusted {
    auto projects = _app.projects.list;
    auto reports = projects.map!(p => _app.reports.projectReport(p.ID)).array;
    auto pageTitle = "Projects";
    auto csrf = csrfHeader(user);
    auto userName = user.userName;
    res.render!("index.dt", pageTitle, projects, reports, csrf, userName);
  }

  private void deadlines(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto alerts = _app.deadlines.alerts;
    res.render!("deadlines.dt", alerts);
  }

  private void projectPage(HTTPServerRequest req, HTTPServerResponse res, Principal user) @trusted {
    auto tab = validTab(req.query.get("tab", "report"));
    auto project = _app.projects.get(req.params["id"]);
    auto pageTitle = project.name;
    auto csrf = csrfHeader(user);
    auto userName = user.userName;
    mixin(panelData);
    res.render!("project.dt", pageTitle, csrf, userName, project, tab, report, activities, consentActivities,
        requests, breaches, consents, events, emailFilter);
  }

  private void panel(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    renderPanel(req, res, req.params["id"], validTab(req.params["tab"]));
  }

  /// Gathers all data the tab templates need (`panel.dt` includes all tabs).
  private enum panelData = q{
    auto projectId = project.ID;
    auto emailFilter = req.query.get("email", "");
    auto report = _app.reports.projectReport(projectId);
    auto activities = _app.activities.list(projectId);
    auto consentActivities = activities.filter!(a => a.legalBasis == "consent").array;
    auto requests = _app.requests.list(projectId);
    auto breaches = _app.breaches.list(projectId);
    auto consents = _app.consents.list(projectId, emailFilter);
    auto events = _app.audit.recent(15, projectId);
  };

  private void renderPanel(HTTPServerRequest req, HTTPServerResponse res, string pid, string tab) @trusted {
    auto project = _app.projects.get(pid);
    mixin(panelData);
    res.render!("panel.dt", project, tab, report, activities, consentActivities, requests, breaches, consents,
        events, emailFilter);
  }

  // -------------------------------------------------------------- projects

  private void createProject(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto p = _app.projects.create(form!CreateProjectInput(req));
    res.headers["HX-Redirect"] = "/web/projects/" ~ urlEncode(p.ID);
    res.writeBody("", "text/plain");
  }

  private void updateProject(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto p = _app.projects.update(req.params["id"], form!UpdateProjectInput(req));
    res.headers["HX-Refresh"] = "true";
    notify(res, "Project '" ~ p.name ~ "' saved");
    res.writeBody("", "text/plain");
  }

  private void deleteProject(HTTPServerRequest req, HTTPServerResponse res, Principal user) @trusted {
    authorize(_app.authGuard, req, "Admin");
    _app.projects.remove(req.params["id"]);
    res.headers["HX-Redirect"] = "/web";
    res.writeBody("", "text/plain");
  }

  // -------------------------------------------------------------- activities

  private void createActivity(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto i = form!CreateActivityInput(req);
    i.projectId = req.params["id"];
    auto a = _app.activities.create(i);
    done(req, res, a.projectId, "activities", "Processing activity '" ~ a.name ~ "' recorded");
  }

  private void updateActivity(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto a = _app.activities.update(req.params["id"], form!UpdateActivityInput(req));
    done(req, res, a.projectId, "activities", "Processing activity '" ~ a.name ~ "' saved");
  }

  private void deleteActivity(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto a = _app.activities.get(req.params["id"]);
    _app.activities.remove(a.ID);
    done(req, res, a.projectId, "activities", "Processing activity deleted");
  }

  // -------------------------------------------------------------- requests

  private void createRequest(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto i = form!CreateRequestInput(req);
    i.projectId = req.params["id"];
    auto r = _app.requests.create(i);
    done(req, res, r.projectId, "requests", "Request recorded – due " ~ r.dueDate);
  }

  private void updateRequest(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto r = _app.requests.update(req.params["id"], form!UpdateRequestInput(req));
    done(req, res, r.projectId, "requests", "Request saved (" ~ label(r.status) ~ ")");
  }

  private void extendRequest(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto r = _app.requests.extend(req.params["id"], req.form.get("reason", ""));
    done(req, res, r.projectId, "requests", "Deadline extended to " ~ r.dueDate);
  }

  private void deleteRequest(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto r = _app.requests.get(req.params["id"]);
    _app.requests.remove(r.ID);
    done(req, res, r.projectId, "requests", "Request deleted");
  }

  // -------------------------------------------------------------- breaches

  private void createBreach(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto i = form!CreateBreachInput(req);
    i.projectId = req.params["id"];
    auto b = _app.breaches.create(i);
    done(req, res, b.projectId, "breaches", b.authorityNotificationRequired
        ? "Breach recorded – notify the authority by " ~ localTime(b.notificationDeadline)
        : "Breach recorded – no notification required (document it)");
  }

  private void updateBreach(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto b = _app.breaches.update(req.params["id"], form!UpdateBreachInput(req));
    done(req, res, b.projectId, "breaches", "Breach saved");
  }

  private void reportBreach(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto b = _app.breaches.reportToAuthority(req.params["id"], req.form.get("at", ""));
    done(req, res, b.projectId, "breaches", b.deadlineMissed ? "Reported – after the deadline, document the reasons" : "Reported to the authority");
  }

  private void notifyBreach(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto b = _app.breaches.notifySubjects(req.params["id"], req.form.get("at", ""));
    done(req, res, b.projectId, "breaches", "Data subjects notified");
  }

  private void closeBreach(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto b = _app.breaches.close(req.params["id"]);
    done(req, res, b.projectId, "breaches", "Breach closed");
  }

  private void deleteBreach(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto b = _app.breaches.get(req.params["id"]);
    _app.breaches.remove(b.ID);
    done(req, res, b.projectId, "breaches", "Breach deleted");
  }

  // -------------------------------------------------------------- consents

  private void createConsent(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto i = form!CreateConsentInput(req);
    i.projectId = req.params["id"];
    auto c = _app.consents.give(i);
    done(req, res, c.projectId, "consents", "Consent recorded");
  }

  private void withdrawConsent(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto c = _app.consents.withdraw(req.params["id"]);
    done(req, res, c.projectId, "consents", "Consent withdrawn");
  }

  private void deleteConsent(HTTPServerRequest req, HTTPServerResponse res, Principal) @trusted {
    auto c = _app.consents.get(req.params["id"]);
    _app.consents.remove(c.ID);
    done(req, res, c.projectId, "consents", "Consent deleted");
  }

  // -------------------------------------------------------------- plumbing

  /// Answers a successful write: notification event + refreshed tab fragment.
  private void done(HTTPServerRequest req, HTTPServerResponse res, string projectId, string tab, string message) @trusted {
    notify(res, message);
    renderPanel(req, res, projectId, tab);
  }

  private static void notify(HTTPServerResponse res, string message) @trusted {
    auto j = Json.emptyObject;
    j["notify"] = message;
    // HTTP headers must be ASCII: non-ASCII characters are escaped as \uXXXX
    res.headers["HX-Trigger"] = asciiJson(j.toString);
  }

  private static T form(T)(HTTPServerRequest req) @trusted {
    return bindStrings!T((string k) @trusted { auto v = k in req.form; return v ? *v : null; });
  }

  /// Wraps a handler with authentication, authorization, CSRF check and error handling.
  private void guarded(alias handler)(HTTPServerRequest req, HTTPServerResponse res) @trusted {
    try {
      auto user = authorize(_app.authGuard, req, requiredScope(req.method.to!string));
      if (req.method == HTTPMethod.POST) {
        ensureNotCrossSite(_app.authGuard, req);
        auto token = req.headers.get("X-CSRF-Token", req.form.get("csrf", ""));
        if (token != csrfToken(user)) throw new ForbiddenException("Invalid or missing CSRF token – please reload the page");
      }
      handler(req, res, user);
    } catch (Exception e) {
      auto info = classify(e);
      if (info.status == HTTPStatus.internalServerError) logException(e, "Web request failed");
      auto message = info.status == HTTPStatus.internalServerError ? "Internal error" : e.msg;
      res.statusCode = info.status;
      if (req.headers.get("HX-Request", "") == "true") {
        res.writeBody(message, "text/plain; charset=utf-8");
      } else {
        res.writeBody("<!doctype html><meta charset=utf-8><title>Error</title><p>" ~ htmlEscape(message)
            ~ "</p><p><a href=\"/web\">Back to overview</a></p>", "text/html; charset=utf-8");
      }
    }
  }

  /// Per-user CSRF token: HMAC-SHA256(secret, user name).
  string csrfToken(Principal user) {
    auto mac = hmac!SHA256(user.userName.representation, _csrfSecret);
    return toHexString(mac).idup;
  }

  /// Value of the global `hx-headers` attribute.
  private string csrfHeader(Principal user) { return `{"X-CSRF-Token": "` ~ csrfToken(user) ~ `"}`; }

  private static string validTab(string tab) {
    import std.algorithm : canFind;
    return projectTabs.canFind(tab) ? tab : "report";
  }

  private static string htmlEscape(string s) {
    import std.array : replace;
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
  }
}

/// Escapes all non-ASCII characters of a JSON text as \uXXXX (UTF-16).
string asciiJson(string s) {
  import std.format : format;
  import std.utf : byDchar;
  string r;
  foreach (dchar c; s.byDchar) {
    if (c < 0x80) r ~= cast(char) c;
    else if (c < 0x10000) r ~= format("\\u%04x", cast(uint) c);
    else {
      auto v = c - 0x10000;
      r ~= format("\\u%04x\\u%04x", 0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF));
    }
  }
  return r;
}

unittest {
  assert(asciiJson(`{"notify":"Request – ok"}`) == `{"notify":"Request \u2013 ok"}`);
}
