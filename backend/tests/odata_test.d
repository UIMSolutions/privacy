/// OData model / metadata consistency checks.
module odata_test;

version (GdprUnittest):

import std.algorithm : canFind;
import uim.myfiori.application.dtos;
import uim.myfiori.presentation.odata;

unittest {
  // every DTO property is declared in the EDM and vice versa
  void check(T)(string set) {
    auto def = findEntitySet(set);
    auto j = toODataJson(T.init);
    foreach (p; def.properties) assert(j[p.name].type != j[p.name].Type.undefined, set ~ "." ~ p.name);
    foreach (string k, v; j) assert(def.properties.canFind!(p => p.name == k), set ~ " missing " ~ k);
  }
  check!ProjectDto("Projects");
  check!ProcessingActivityDto("ProcessingActivities");
  check!DataSubjectRequestDto("DataSubjectRequests");
  check!DataBreachDto("DataBreaches");
  check!ConsentDto("Consents");

  auto report = toODataJson(ProjectReportDto.init);
  foreach (p; reportProperties) assert(report[p.name].type != report[p.name].Type.undefined, p.name);

  auto xml = buildMetadata;
  assert(xml.canFind(`<NavigationProperty Name="requests" Type="Collection(gdpr.DataSubjectRequest)"/>`));
  assert(xml.canFind(`<FunctionImport Name="GetProjectReport" Function="gdpr.GetProjectReport"/>`));
}
