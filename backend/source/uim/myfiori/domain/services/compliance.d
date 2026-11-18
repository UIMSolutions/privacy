/**
 * Compliance assessment of a GDPR project: derives findings (gaps) from the
 * registers and a compliance score (100 = no open findings).
 */
module uim.myfiori.domain.services.compliance;

@safe:

import std.algorithm : max;
import std.format : format;

/// Aggregated register figures used for the assessment.
struct ComplianceFigures {
  int activities;
  int activitiesActive;
  int activitiesDraft;
  int dpiaRequired;
  int dpiaOpen;                 // DPIA required but not completed
  int transfersWithoutSafeguard;
  int requestsOpen;
  int requestsOverdue;
  int breachesOpen;
  int breachesDeadlineMissed;
  int breachesNotReported;      // notification required, not yet made
  int breachesSubjectsPending;  // Art. 34 communication outstanding
  int consentActivitiesWithoutConsents;
  bool dpoAppointed;
}

struct Finding {
  string severity;   // high | medium | low
  string article;
  string text;
}

Finding[] assessCompliance(ComplianceFigures f) pure {
  Finding[] r;
  if (!f.dpoAppointed) r ~= Finding("medium", "Art. 37", "No data protection officer recorded for the project");
  if (f.activities == 0) r ~= Finding("high", "Art. 30", "Record of processing activities is empty");
  if (f.activitiesDraft) r ~= Finding("low", "Art. 30", format("%d processing activit%s still in draft", f.activitiesDraft, f.activitiesDraft == 1 ? "y" : "ies"));
  if (f.dpiaOpen) r ~= Finding("high", "Art. 35", format("%d processing activit%s a DPIA that is not completed", f.dpiaOpen, f.dpiaOpen == 1 ? "y requires" : "ies require"));
  if (f.transfersWithoutSafeguard) r ~= Finding("high", "Art. 44", format("%d third-country transfer(s) without documented safeguard", f.transfersWithoutSafeguard));
  if (f.requestsOverdue) r ~= Finding("high", "Art. 12 (3)", format("%d data subject request(s) overdue", f.requestsOverdue));
  if (f.breachesNotReported) r ~= Finding("high", "Art. 33", format("%d breach(es) requiring notification not reported to the authority", f.breachesNotReported));
  if (f.breachesDeadlineMissed) r ~= Finding("medium", "Art. 33 (1)", format("%d breach notification(s) later than 72 hours – reasons for the delay must be documented", f.breachesDeadlineMissed));
  if (f.breachesSubjectsPending) r ~= Finding("high", "Art. 34", format("%d high-risk breach(es) without communication to data subjects", f.breachesSubjectsPending));
  if (f.consentActivitiesWithoutConsents) r ~= Finding("low", "Art. 7 (1)", format("%d consent-based activit%s without recorded consents (proof of consent)", f.consentActivitiesWithoutConsents, f.consentActivitiesWithoutConsents == 1 ? "y" : "ies"));
  return r;
}

/// 100 minus weighted findings (high 20, medium 10, low 5), never below 0.
double complianceScore(const Finding[] findings) pure nothrow {
  int penalty;
  foreach (f; findings) penalty += f.severity == "high" ? 20 : f.severity == "medium" ? 10 : 5;
  return max(0, 100 - penalty);
}

unittest {
  ComplianceFigures f;
  f.dpoAppointed = true;
  f.activities = 2;
  f.activitiesActive = 2;
  assert(assessCompliance(f).length == 0 && complianceScore(assessCompliance(f)) == 100);
  f.requestsOverdue = 1;
  f.dpoAppointed = false;
  assert(complianceScore(assessCompliance(f)) == 70);
}
