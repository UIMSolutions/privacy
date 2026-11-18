/// CSDL ($metadata) and service document generation for the OData v4 service.
module uim.myfiori.presentation.odata.metadata;

@safe:

import std.array : appender;
import uim.myfiori.presentation.odata.model;

/// Unbound operations: name, kind, parameters (name:type), return type.
struct OperationDef {
  string name;
  bool isAction;
  string[2][] parameters;
  string returnType;
  string entitySet;        // for actions returning an entity
}

OperationDef[] operations() {
  enum ns = odataNamespace;
  return [
    OperationDef("GetProjectReport", false, [["projectId", "Edm.String"]], ns ~ ".ProjectReport"),
    OperationDef("ExtendRequest", true, [["requestId", "Edm.String"], ["reason", "Edm.String"]],
      ns ~ ".DataSubjectRequest", "DataSubjectRequests"),
    OperationDef("ReportBreach", true, [["breachId", "Edm.String"], ["reportedAt", "Edm.DateTimeOffset"]],
      ns ~ ".DataBreach", "DataBreaches"),
    OperationDef("NotifyBreachSubjects", true, [["breachId", "Edm.String"], ["notifiedAt", "Edm.DateTimeOffset"]],
      ns ~ ".DataBreach", "DataBreaches"),
    OperationDef("CloseBreach", true, [["breachId", "Edm.String"]], ns ~ ".DataBreach", "DataBreaches"),
    OperationDef("WithdrawConsent", true, [["consentId", "Edm.String"], ["withdrawnAt", "Edm.DateTimeOffset"]],
      ns ~ ".Consent", "Consents"),
  ];
}

private void writeProperty(A)(ref A w, PropertyDef p) {
  auto type = p.collection ? "Collection(" ~ p.type ~ ")" : p.type;
  w ~= `<Property Name="` ~ p.name ~ `" Type="` ~ type ~ `"`;
  if (!p.nullable) w ~= ` Nullable="false"`;
  if (p.type == "Edm.DateTimeOffset") w ~= ` Precision="0"`;
  if (p.computed) w ~= `><Annotation Term="Core.Computed" Bool="true"/></Property>`;
  else w ~= `/>`;
}

/// Builds the complete CSDL XML document.
string buildMetadata() {
  enum ns = odataNamespace;
  auto w = appender!string;
  w ~= `<?xml version="1.0" encoding="utf-8"?>`;
  w ~= `<edmx:Edmx xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx" Version="4.0">`;
  w ~= `<edmx:Reference Uri="https://oasis-tcs.github.io/odata-vocabularies/vocabularies/Org.OData.Core.V1.xml">`;
  w ~= `<edmx:Include Namespace="Org.OData.Core.V1" Alias="Core"/></edmx:Reference>`;
  w ~= `<edmx:DataServices><Schema xmlns="http://docs.oasis-open.org/odata/ns/edm" Namespace="` ~ ns ~ `">`;

  foreach (t; entityTypes) {
    w ~= `<EntityType Name="` ~ t.name ~ `"><Key><PropertyRef Name="` ~ t.key ~ `"/></Key>`;
    foreach (p; t.properties) writeProperty(w, p);
    foreach (n; t.navigations)
      w ~= `<NavigationProperty Name="` ~ n.name ~ `" Type="Collection(` ~ ns ~ "." ~ n.targetType ~ `)"/>`;
    w ~= `</EntityType>`;
  }

  w ~= `<ComplexType Name="Finding">`;
  foreach (p; findingProperties) writeProperty(w, PropertyDef(p.name, p.type, p.nullable));
  w ~= `</ComplexType><ComplexType Name="ProjectReport">`;
  foreach (p; reportProperties) writeProperty(w, PropertyDef(p.name, p.type, p.nullable, false, p.collection));
  w ~= `</ComplexType>`;

  foreach (op; operations) {
    w ~= (op.isAction ? `<Action Name="` : `<Function Name="`) ~ op.name ~ `">`;
    foreach (i, p; op.parameters)
      w ~= `<Parameter Name="` ~ p[0] ~ `" Type="` ~ p[1] ~ `"` ~ (i == 0 ? ` Nullable="false"` : "") ~ `/>`;
    w ~= `<ReturnType Type="` ~ op.returnType ~ `" Nullable="false"/>`;
    w ~= op.isAction ? `</Action>` : `</Function>`;
  }

  w ~= `<EntityContainer Name="EntityContainer">`;
  foreach (t; entityTypes) {
    w ~= `<EntitySet Name="` ~ t.entitySet ~ `" EntityType="` ~ ns ~ "." ~ t.name ~ `">`;
    foreach (n; t.navigations)
      w ~= `<NavigationPropertyBinding Path="` ~ n.name ~ `" Target="` ~ n.targetSet ~ `"/>`;
    w ~= `</EntitySet>`;
  }
  foreach (op; operations) {
    if (op.isAction)
      w ~= `<ActionImport Name="` ~ op.name ~ `" Action="` ~ ns ~ "." ~ op.name ~ `" EntitySet="` ~ op.entitySet ~ `"/>`;
    else
      w ~= `<FunctionImport Name="` ~ op.name ~ `" Function="` ~ ns ~ "." ~ op.name ~ `"/>`;
  }
  w ~= `</EntityContainer></Schema></edmx:DataServices></edmx:Edmx>`;
  return w.data;
}

/// Service document (JSON) listing all entity sets and the function import.
string buildServiceDocument(string metadataUrl) {
  import vibe.data.json : Json;
  auto values = Json.emptyArray;
  foreach (t; entityTypes) {
    auto e = Json.emptyObject;
    e["name"] = t.entitySet;
    e["kind"] = "EntitySet";
    e["url"] = t.entitySet;
    values ~= e;
  }
  foreach (op; operations) if (!op.isAction) {
    auto f = Json.emptyObject;
    f["name"] = op.name;
    f["kind"] = "FunctionImport";
    f["url"] = op.name;
    values ~= f;
  }
  auto doc = Json.emptyObject;
  doc["@odata.context"] = metadataUrl;
  doc["value"] = values;
  return doc.toString;
}

unittest {
  import std.algorithm : canFind;
  auto xml = buildMetadata;
  assert(xml.canFind(`<EntitySet Name="Projects" EntityType="gdpr.Project">`));
  assert(xml.canFind(`<Property Name="findings" Type="Collection(gdpr.Finding)" Nullable="false"/>`));
  assert(xml.canFind(`<ActionImport Name="WithdrawConsent" Action="gdpr.WithdrawConsent" EntitySet="Consents"/>`));
}
