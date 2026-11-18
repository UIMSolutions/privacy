/**
 * Entity data model (EDM) of the OData v4 service. Entity types are derived from
 * the read DTOs at compile time; this module adds keys, computed flags,
 * navigation properties and the DTO → JSON conversion.
 */
module uim.myfiori.presentation.odata.model;

@safe:

import std.algorithm : canFind, endsWith;
import std.traits : FieldNameTuple;
import vibe.data.json;
import uim.myfiori.application.dtos;

enum odataNamespace = "gdpr";
enum odataBasePath = "/odata/v4/gdpr";

struct PropertyDef {
  string name;
  string type = "Edm.String";
  bool nullable = true;
  bool computed;
  bool collection;
}

struct NavigationDef {
  string name;
  string targetType;
  string targetSet;
}

struct EntityTypeDef {
  string name;
  string entitySet;
  string key = "ID";
  PropertyDef[] properties;
  NavigationDef[] navigations;
}

/// EDM type of a DTO field (dates are transported as ISO strings).
string edmType(T)(string field) {
  static if (is(T == bool)) return "Edm.Boolean";
  else static if (is(T == int)) return "Edm.Int32";
  else static if (is(T == long)) return "Edm.Int64";
  else static if (is(T == double)) return "Edm.Double";
  else {
    if (field.endsWith("At") || field == "notificationDeadline") return "Edm.DateTimeOffset";
    if (field.endsWith("On") || field == "dueDate") return "Edm.Date";
    return "Edm.String";
  }
}

/// Properties of DTO type D; `writable` lists the client-settable fields, everything else is computed.
PropertyDef[] propertiesOf(D)(string[] writable, string[] required) {
  PropertyDef[] r;
  static foreach (name; FieldNameTuple!D) {{
    alias F = typeof(__traits(getMember, D, name));
    static if (!is(F == U[], U) || is(F == string)) {
      auto type = edmType!F(name);
      bool notNull = name == "ID" || required.canFind(name) || (type != "Edm.String" && type != "Edm.Date"
          && type != "Edm.DateTimeOffset");
      r ~= PropertyDef(name, type, !notNull, name == "ID" || !writable.canFind(name));
    }
  }}
  return r;
}

EntityTypeDef[] entityTypes() {
  return [
    EntityTypeDef("Project", "Projects", "ID",
      propertiesOf!ProjectDto(["name", "description", "controller", "dpoName", "dpoEmail", "status"], ["name"]), [
        NavigationDef("activities", "ProcessingActivity", "ProcessingActivities"),
        NavigationDef("requests", "DataSubjectRequest", "DataSubjectRequests"),
        NavigationDef("breaches", "DataBreach", "DataBreaches"),
        NavigationDef("consents", "Consent", "Consents"),
      ]),
    EntityTypeDef("ProcessingActivity", "ProcessingActivities", "ID",
      propertiesOf!ProcessingActivityDto(["projectId", "name", "purpose", "legalBasis", "dataCategories",
        "dataSubjects", "recipients", "retentionPeriod", "toms", "specialCategories", "largeScale",
        "systematicMonitoring", "automatedDecisions", "thirdCountryTransfer", "transferSafeguard", "dpiaCompleted",
        "status"], ["projectId", "name"])),
    EntityTypeDef("DataSubjectRequest", "DataSubjectRequests", "ID",
      propertiesOf!DataSubjectRequestDto(["projectId", "type", "subjectName", "subjectEmail", "description",
        "receivedOn", "status", "resolution"], ["projectId", "type", "subjectName"])),
    EntityTypeDef("DataBreach", "DataBreaches", "ID",
      propertiesOf!DataBreachDto(["projectId", "title", "description", "detectedAt", "severity",
        "affectedSubjects", "dataCategories", "measures"], ["projectId", "title"])),
    EntityTypeDef("Consent", "Consents", "ID",
      propertiesOf!ConsentDto(["projectId", "activityId", "subjectEmail", "purpose", "textVersion", "channel",
        "givenAt"], ["projectId", "subjectEmail", "purpose"])),
  ];
}

/// Complex type returned by GetProjectReport.
PropertyDef[] reportProperties() {
  auto p = propertiesOf!ProjectReportDto(null, null);
  p ~= PropertyDef("findings", odataNamespace ~ ".Finding", false, false, true);
  return p;
}

PropertyDef[] findingProperties() { return propertiesOf!FindingDto(null, null); }

EntityTypeDef findEntitySet(string set) {
  foreach (t; entityTypes) if (t.entitySet == set) return t;
  return EntityTypeDef.init;
}

/// Serialises a DTO; empty date/timestamp values become null.
Json toODataJson(T)(T dto) @trusted {
  auto j = serializeToJson(dto);
  static foreach (name; FieldNameTuple!T) {{
    alias F = typeof(__traits(getMember, T, name));
    static if (is(F == string)) {
      auto type = edmType!F(name);
      if ((type == "Edm.Date" || type == "Edm.DateTimeOffset") && j[name].get!string.length == 0) j[name] = Json(null);
    }
  }}
  return j;
}

unittest {
  auto t = findEntitySet("DataSubjectRequests");
  assert(t.name == "DataSubjectRequest");
  foreach (p; t.properties) {
    if (p.name == "dueDate") assert(p.type == "Edm.Date" && p.computed);
    if (p.name == "overdue") assert(p.type == "Edm.Boolean" && !p.nullable && p.computed);
    if (p.name == "subjectName") assert(!p.nullable && !p.computed);
  }
  DataSubjectRequestDto d;
  assert(toODataJson(d)["closedOn"].type == Json.Type.null_);
}
