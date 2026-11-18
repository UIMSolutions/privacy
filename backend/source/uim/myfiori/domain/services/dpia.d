/**
 * DPIA screening (Art. 35 GDPR). Follows the WP29/EDPB guideline (WP 248): a data
 * protection impact assessment is needed when two or more high-risk criteria apply;
 * large-scale processing of special categories (Art. 35 (3) b) always requires one.
 */
module uim.myfiori.domain.services.dpia;

@safe:

import uim.myfiori.domain.enumerations : RiskLevel;

struct DpiaCriteria {
  bool specialCategories;
  bool largeScale;
  bool systematicMonitoring;
  bool automatedDecisions;
  bool thirdCountryTransfer;
}

struct DpiaAssessment {
  int criteriaMet;
  RiskLevel riskLevel;
  bool dpiaRequired;
}

DpiaAssessment assessDpia(DpiaCriteria c) pure nothrow {
  int n = c.specialCategories + c.largeScale + c.systematicMonitoring + c.automatedDecisions + c.thirdCountryTransfer;
  DpiaAssessment a;
  a.criteriaMet = n;
  a.dpiaRequired = n >= 2 || (c.specialCategories && c.largeScale) || (c.systematicMonitoring && c.largeScale);
  a.riskLevel = a.dpiaRequired ? RiskLevel.high : n == 1 ? RiskLevel.medium : RiskLevel.low;
  return a;
}

unittest {
  assert(assessDpia(DpiaCriteria.init).riskLevel == RiskLevel.low);
  assert(assessDpia(DpiaCriteria(true)).riskLevel == RiskLevel.medium);
  assert(assessDpia(DpiaCriteria(true, true)).dpiaRequired);
  assert(assessDpia(DpiaCriteria(false, false, true, true)).riskLevel == RiskLevel.high);
}
