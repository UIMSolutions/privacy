/**
 * OData v4 endpoint for SAP Fiori / UI5 (sap.ui.model.odata.v4.ODataModel).
 *
 * Supported: service document, $metadata, entity sets with $filter/$orderby/$top/$skip/
 * $count/$select, single entities by key, navigation collections of Projects (incl. create
 * via navigation), POST/PATCH/PUT/DELETE, function import GetProjectReport and the action
 * imports ExtendRequest, ReportBreach, NotifyBreachSubjects, CloseBreach, WithdrawConsent.
 * $batch is not supported — the UI5 model is configured with groupId "$direct".
 */
module uim.myfiori.presentation.odata.service;

@safe:

import std.algorithm : map;
import std.array : array, replace, split;
import std.conv : to;
import std.string : indexOf, startsWith;
import vibe.core.log;
import vibe.data.json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.textfilter.urlencode : urlDecode;

import uim.myfiori.application.dtos;
import uim.myfiori.bootstrap;
import uim.myfiori.infrastructure.security : requiredScope;
import uim.myfiori.presentation.http.auth;
import uim.myfiori.presentation.http.binding;
import uim.myfiori.presentation.http.errors;
import uim.myfiori.presentation.odata.metadata;
import uim.myfiori.presentation.odata.model;
import uim.myfiori.presentation.odata.query;

/// One parsed path segment: name plus optional key / parameter list.
struct Segment {
  string name;
  bool hasKey;
  string key;
  string[string] params;
}

/// Parses "Name", "Name('k')", "Name(ID='k')" and "Name(a='x',b=1)".
Segment parseSegment(string raw) {
  Segment s;
  auto open = raw.indexOf('(');
  if (open < 0 || raw[$ - 1] != ')') { s.name = raw; return s; }
  s.name = raw[0 .. open];
  s.hasKey = true;
  string[] parts;
  string cur;
  bool quoted;
  foreach (c; raw[open + 1 .. $ - 1]) {
    if (c == '\'') quoted = !quoted;
    if (c == ',' && !quoted) { parts ~= cur; cur = null; } else cur ~= c;
  }
  if (cur.length) parts ~= cur;
  foreach (p; parts) {
    auto eq = p.indexOf('=');
    if (eq > 0 && p[0] != '\'') s.params[p[0 .. eq]] = literal(p[eq + 1 .. $]);
    else s.key = literal(p);
  }
  if (s.key.length == 0 && s.params.length == 1) s.key = s.params.byValue.front;
  return s;
}

private string literal(string v) {
  if (v.length >= 2 && v[0] == '\'' && v[$ - 1] == '\'') return v[1 .. $ - 1].replace("''", "'");
  return v;
}

/// CRUD bridge from an entity set to its use cases.
struct EntitySetHandler {
  Json[] delegate() @safe list;
  Json[] delegate(string projectId) @safe listByProject;
  Json delegate(string) @safe read;
  Json delegate(Json) @safe create;
  Json delegate(string, Json) @safe update;
  void delegate(string) @safe remove;
}

class DODataService {
  private DApplicationContainer _app;
  private string _base;
  private string _csrfToken;
  private EntitySetHandler[string] _handlers;

  this(DApplicationContainer app, string base = odataBasePath) {
    import std.uuid : randomUUID;
    _app = app;
    _base = base;
    _csrfToken = randomUUID.toString;
    registerHandlers();
  }

  void register(URLRouter router) {
    router.any(_base, &handle);
    router.any(_base ~ "/*", &handle);
  }

  private void registerHandlers() {
    auto a = _app;
    _handlers["Projects"] = EntitySetHandler(
      () => a.projects.list.map!(d => toODataJson(d)).array,
      null,
      (string id) => toODataJson(a.projects.get(id)),
      (Json b) => toODataJson(a.projects.create(bindJson!CreateProjectInput(b))),
      (string id, Json b) => toODataJson(a.projects.update(id, bindJson!UpdateProjectInput(b))),
      (string id) { a.projects.remove(id); });
    _handlers["ProcessingActivities"] = EntitySetHandler(
      () => a.activities.list.map!(d => toODataJson(d)).array,
      (string p) => a.activities.list(p).map!(d => toODataJson(d)).array,
      (string id) => toODataJson(a.activities.get(id)),
      (Json b) => toODataJson(a.activities.create(bindJson!CreateActivityInput(b))),
      (string id, Json b) => toODataJson(a.activities.update(id, bindJson!UpdateActivityInput(b))),
      (string id) { a.activities.remove(id); });
    _handlers["DataSubjectRequests"] = EntitySetHandler(
      () => a.requests.list.map!(d => toODataJson(d)).array,
      (string p) => a.requests.list(p).map!(d => toODataJson(d)).array,
      (string id) => toODataJson(a.requests.get(id)),
      (Json b) => toODataJson(a.requests.create(bindJson!CreateRequestInput(b))),
      (string id, Json b) => toODataJson(a.requests.update(id, bindJson!UpdateRequestInput(b))),
      (string id) { a.requests.remove(id); });
    _handlers["DataBreaches"] = EntitySetHandler(
      () => a.breaches.list.map!(d => toODataJson(d)).array,
      (string p) => a.breaches.list(p).map!(d => toODataJson(d)).array,
      (string id) => toODataJson(a.breaches.get(id)),
      (Json b) => toODataJson(a.breaches.create(bindJson!CreateBreachInput(b))),
      (string id, Json b) => toODataJson(a.breaches.update(id, bindJson!UpdateBreachInput(b))),
      (string id) { a.breaches.remove(id); });
    _handlers["Consents"] = EntitySetHandler(
      () => a.consents.list.map!(d => toODataJson(d)).array,
      (string p) => a.consents.list(p).map!(d => toODataJson(d)).array,
      (string id) => toODataJson(a.consents.get(id)),
      (Json b) => toODataJson(a.consents.give(bindJson!CreateConsentInput(b))),
      (string id, Json b) => toODataJson(a.consents.update(id, bindJson!UpdateConsentInput(b))),
      (string id) { a.consents.remove(id); });
  }

  void handle(HTTPServerRequest req, HTTPServerResponse res) @trusted {
    res.headers["OData-Version"] = "4.0";
    res.headers["Cache-Control"] = "no-store";
    // CSRF protection is enforced by the approuter; the token is handed out for UI5 compatibility.
    if (req.headers.get("X-CSRF-Token", "") == "Fetch") res.headers["X-CSRF-Token"] = _csrfToken;
    try {
      authorize(_app.authGuard, req, requiredScope(req.method.to!string));
      ensureNotCrossSite(_app.authGuard, req);
      dispatch(req, res);
    } catch (Exception e) {
      auto info = classify(e);
      if (info.status == HTTPStatus.internalServerError) logException(e, "OData request failed");
      writeError(res, info.status, info.code, info.status == HTTPStatus.internalServerError ? "Internal server error" : e.msg);
    }
  }

  private void dispatch(HTTPServerRequest req, HTTPServerResponse res) @trusted {
    auto path = req.requestPath.toString;
    auto rel = path.length > _base.length ? path[_base.length .. $] : "";
    if (rel.startsWith("/")) rel = rel[1 .. $];
    rel = urlDecode(rel);

    if (rel.length == 0) {
      if (req.method == HTTPMethod.HEAD) { res.writeVoidBody; return; }
      return writeJsonText(res, HTTPStatus.ok, buildServiceDocument(_base ~ "/$metadata"));
    }
    if (rel == "$metadata") {
      res.writeBody(buildMetadata, "application/xml");
      return;
    }
    if (rel == "$batch") throw new BadRequestException("$batch is not supported; use groupId $direct");

    auto segs = rel.split("/").map!(s => parseSegment(s)).array;
    if (operation(req, res, segs[0])) return;

    auto set = findEntitySet(segs[0].name);
    if (set.name.length == 0) throw new BadRequestException("Unknown resource '" ~ segs[0].name ~ "'");
    auto h = _handlers[set.entitySet];
    auto q = parseQueryOptions((string k) @safe => req.query.get(k, null));

    if (segs.length == 1 && !segs[0].hasKey) {
      if (req.method == HTTPMethod.GET || req.method == HTTPMethod.HEAD)
        return writeCollection(res, set.entitySet, h.list(), q);
      ensureMethod(req, HTTPMethod.POST);
      return created(res, set.entitySet, h.create(body_(req)));
    }
    if (segs.length == 2 && !segs[0].hasKey && segs[1].name == "$count") {
      ensureMethod(req, HTTPMethod.GET);
      return writeCount(res, h.list(), q);
    }
    if (segs.length == 1) return entity(req, res, set.entitySet, h, segs[0].key);
    if (segs.length >= 2 && segs[0].hasKey && set.entitySet == "Projects")
      return navigation(req, res, segs[0].key, segs[1].name, segs.length == 3 && segs[2].name == "$count", q);
    throw new BadRequestException("Unsupported resource path '" ~ rel ~ "'");
  }

  /// Function / action imports; returns false if the segment is no operation.
  private bool operation(HTTPServerRequest req, HTTPServerResponse res, Segment seg) @trusted {
    switch (seg.name) {
      case "GetProjectReport":
        ensureMethod(req, HTTPMethod.GET);
        auto projectId = seg.params.get("projectId", seg.key);
        if (projectId.startsWith("@")) projectId = literal(req.query.get(projectId, ""));
        auto j = toODataJson(_app.reports.projectReport(projectId));
        j["@odata.context"] = _base ~ "/$metadata#" ~ odataNamespace ~ ".ProjectReport";
        writeJson(res, HTTPStatus.ok, j);
        return true;
      case "ExtendRequest":
        auto b = actionBody(req);
        return entityResult(res, "DataSubjectRequests", toODataJson(_app.requests.extend(param(b, "requestId"), param(b, "reason", ""))));
      case "ReportBreach":
        auto b = actionBody(req);
        return entityResult(res, "DataBreaches", toODataJson(_app.breaches.reportToAuthority(param(b, "breachId"), param(b, "reportedAt", ""))));
      case "NotifyBreachSubjects":
        auto b = actionBody(req);
        return entityResult(res, "DataBreaches", toODataJson(_app.breaches.notifySubjects(param(b, "breachId"), param(b, "notifiedAt", ""))));
      case "CloseBreach":
        auto b = actionBody(req);
        return entityResult(res, "DataBreaches", toODataJson(_app.breaches.close(param(b, "breachId"))));
      case "WithdrawConsent":
        auto b = actionBody(req);
        return entityResult(res, "Consents", toODataJson(_app.consents.withdraw(param(b, "consentId"), param(b, "withdrawnAt", ""))));
      default:
        return false;
    }
  }

  private void navigation(HTTPServerRequest req, HTTPServerResponse res, string projectId, string nav,
      bool countOnly, QueryOptions q) @trusted {
    string target;
    foreach (n; findEntitySet("Projects").navigations) if (n.name == nav) target = n.targetSet;
    if (target.length == 0) throw new BadRequestException("Unknown navigation property '" ~ nav ~ "'");
    auto h = _handlers[target];
    _app.projects.get(projectId);   // 404 if missing

    if (req.method == HTTPMethod.POST) {
      auto b = body_(req);
      b["projectId"] = projectId;
      return created(res, target, h.create(b));
    }
    ensureMethod(req, HTTPMethod.GET);
    auto items = h.listByProject(projectId);
    if (countOnly) return writeCount(res, items, q);
    writeCollection(res, target, items, q);
  }

  private void entity(HTTPServerRequest req, HTTPServerResponse res, string set, EntitySetHandler h, string key) @trusted {
    switch (req.method) {
      case HTTPMethod.GET:
      case HTTPMethod.HEAD:
        return writeEntity(res, HTTPStatus.ok, set, h.read(key));
      case HTTPMethod.PATCH:
      case HTTPMethod.PUT:
        return writeEntity(res, HTTPStatus.ok, set, h.update(key, body_(req)));
      case HTTPMethod.DELETE:
        if (set == "Projects") authorize(_app.authGuard, req, "Admin");
        h.remove(key);
        res.statusCode = HTTPStatus.noContent;
        res.writeVoidBody;
        return;
      default:
        throw new BadRequestException("Method " ~ req.method.to!string ~ " not allowed");
    }
  }

  // -------------------------------------------------------------- response helpers

  private void created(HTTPServerResponse res, string set, Json entity) @trusted {
    res.headers["Location"] = _base ~ "/" ~ set ~ "('" ~ entity["ID"].get!string ~ "')";
    writeEntity(res, HTTPStatus.created, set, entity);
  }

  private bool entityResult(HTTPServerResponse res, string set, Json entity) {
    writeEntity(res, HTTPStatus.ok, set, entity);
    return true;
  }

  private void writeCollection(HTTPServerResponse res, string set, Json[] items, QueryOptions q) {
    auto r = applyQuery(items, q, "ID");
    auto doc = Json.emptyObject;
    doc["@odata.context"] = _base ~ "/$metadata#" ~ set;
    if (q.count) doc["@odata.count"] = r.count;
    doc["value"] = Json(r.items);
    writeJson(res, HTTPStatus.ok, doc);
  }

  private static void writeCount(HTTPServerResponse res, Json[] items, QueryOptions q) @trusted {
    q.top = -1;
    q.skip = 0;
    res.writeBody(applyQuery(items, q, "ID").count.to!string, "text/plain");
  }

  private void writeEntity(HTTPServerResponse res, HTTPStatus status, string set, Json entity) {
    entity["@odata.context"] = _base ~ "/$metadata#" ~ set ~ "/$entity";
    writeJson(res, status, entity);
  }

  private static Json actionBody(HTTPServerRequest req) {
    ensureMethod(req, HTTPMethod.POST);
    return body_(req);
  }

  private static string param(Json b, string name) {
    auto v = param(b, name, null);
    if (v.length == 0) throw new BadRequestException("Parameter '" ~ name ~ "' is required");
    return v;
  }

  private static string param(Json b, string name, string fallback) @trusted {
    auto v = b[name];
    if (v.type == Json.Type.undefined || v.type == Json.Type.null_) return fallback;
    if (v.type != Json.Type.string) throw new BadRequestException("Parameter '" ~ name ~ "' must be a string");
    return v.get!string;
  }

  private static Json body_(HTTPServerRequest req) @trusted {
    import vibe.stream.operations : readAllUTF8;
    auto text = req.bodyReader.readAllUTF8;
    if (text.length == 0) return Json.emptyObject;
    try {
      auto j = parseJsonString(text);
      if (j.type != Json.Type.object) throw new BadRequestException("Request body must be a JSON object");
      return j;
    } catch (JSONException e) throw new BadRequestException("Malformed JSON: " ~ e.msg);
  }

  private static void ensureMethod(HTTPServerRequest req, HTTPMethod m) {
    if (req.method != m && !(m == HTTPMethod.GET && req.method == HTTPMethod.HEAD))
      throw new BadRequestException("Method " ~ req.method.to!string ~ " not allowed here");
  }

  private static void writeJson(HTTPServerResponse res, HTTPStatus status, Json j) @trusted {
    writeJsonText(res, status, j.toString);
  }

  private static void writeJsonText(HTTPServerResponse res, HTTPStatus status, string text) @trusted {
    res.statusCode = status;
    res.writeBody(text, "application/json;odata.metadata=minimal;charset=utf-8");
  }

  private static void writeError(HTTPServerResponse res, HTTPStatus status, string code, string message) @trusted {
    auto e = Json.emptyObject;
    e["code"] = code;
    e["message"] = message;
    auto doc = Json.emptyObject;
    doc["error"] = e;
    writeJsonText(res, status, doc.toString);
  }
}

unittest {
  auto s = parseSegment("Projects('a''b')");
  assert(s.name == "Projects" && s.hasKey && s.key == "a'b");
  s = parseSegment("GetProjectReport(projectId='x1')");
  assert(s.params["projectId"] == "x1" && s.key == "x1");
}
