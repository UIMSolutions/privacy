/// View helpers for the Diet templates (labels, BeerCSS colour classes, formatting).
module uim.myfiori.presentation.web.helpers;

@safe:

import std.datetime.systime : SysTime;
import std.format : format;
import uim.myfiori.domain.enumerations;

/// Human readable label for an enum value transported in DTOs.
string label(string value) pure nothrow {
  switch (value) {
    case "planned": return "Planned";
    case "inProgress": return "In progress";
    case "completed": return "Completed";
    case "archived": return "Archived";
    case "consent": return "Consent";
    case "contract": return "Contract";
    case "legalObligation": return "Legal obligation";
    case "vitalInterests": return "Vital interests";
    case "publicTask": return "Public task";
    case "legitimateInterests": return "Legitimate interests";
    case "draft": return "Draft";
    case "active": return "Active";
    case "retired": return "Retired";
    case "low": return "Low";
    case "medium": return "Medium";
    case "high": return "High";
    case "access": return "Access";
    case "rectification": return "Rectification";
    case "erasure": return "Erasure";
    case "restriction": return "Restriction";
    case "portability": return "Portability";
    case "objection": return "Objection";
    case "received": return "Received";
    case "verified": return "Identity verified";
    case "rejected": return "Rejected";
    case "open": return "Open";
    case "reported": return "Reported";
    case "closed": return "Closed";
    case "web": return "Web";
    case "app": return "App";
    case "email": return "E-mail";
    case "paper": return "Paper";
    case "phone": return "Phone";
    case "other": return "Other";
    default: return value;
  }
}

/// BeerCSS text/border colour classes for a status, level or severity.
string tone(string value) pure nothrow {
  switch (value) {
    case "completed", "active", "low", "closed", "verified": return "green-border green-text";
    case "inProgress", "medium", "received", "reported", "planned": return "orange-border orange-text";
    case "high", "rejected", "open": return "red-border red-text";
    default: return "grey-border grey-text";
  }
}

/// Colour of the compliance score.
string scoreTone(double score) pure nothrow {
  return score >= 80 ? "green-text" : score >= 50 ? "orange-text" : "red-text";
}

string percent(double v) { return format("%.0f %%", v); }

/// "2026-11-18T09:30:00Z" → "2026-11-18 10:30" (server local time); "" stays "".
string localTime(string iso) @trusted {
  if (iso.length == 0) return "";
  try {
    auto t = SysTime.fromISOExtString(iso).toLocalTime;
    return format("%04d-%02d-%02d %02d:%02d", t.year, t.month, t.day, t.hour, t.minute);
  } catch (Exception) return iso;
}

/// Value for an <input type="datetime-local">.
string inputTime(string iso) @trusted {
  auto s = localTime(iso);
  return s.length == 16 ? s[0 .. 10] ~ "T" ~ s[11 .. $] : "";
}

/// "in 5 days" / "3 days overdue".
string daysText(long days) {
  if (days == 0) return "due today";
  return days > 0 ? format("%d day%s left", days, days == 1 ? "" : "s") : format("%d day%s overdue", -days, days == -1 ? "" : "s");
}

/// ditto for hours.
string hoursText(long hours) {
  if (hours >= 0) return format("%d h left", hours);
  return format("%d h overdue", -hours);
}

string shortId(string id) pure nothrow { return id.length > 8 ? id[0 .. 8] : id; }

/// GDPR article of a request type / legal basis value.
string articleOf(string value) {
  foreach (t; enumNames!RequestType) if (t == value) return article(parseEnum!RequestType(value, "type"));
  foreach (b; enumNames!LegalBasis) if (b == value) return article(parseEnum!LegalBasis(value, "legalBasis"));
  return "";
}

immutable string[] projectStatuses = enumNames!ProjectStatus;
immutable string[] legalBases = enumNames!LegalBasis;
immutable string[] activityStatuses = enumNames!ActivityStatus;
immutable string[] requestTypes = enumNames!RequestType;
immutable string[] requestStatuses = enumNames!RequestStatus;
immutable string[] breachSeverities = enumNames!BreachSeverity;
immutable string[] consentChannels = enumNames!ConsentChannel;

unittest {
  assert(label("legitimateInterests") == "Legitimate interests");
  assert(daysText(-2) == "2 days overdue" && daysText(1) == "1 day left");
  assert(articleOf("erasure") == "Art. 17" && articleOf("consent") == "Art. 6 (1) a");
}

/// Tabs of the project page.
immutable string[] projectTabs = ["report", "activities", "requests", "breaches", "consents"];

string tabLabel(string tab) pure nothrow {
  switch (tab) {
    case "activities": return "Processing activities";
    case "requests": return "Data subject requests";
    case "breaches": return "Data breaches";
    case "consents": return "Consents";
    default: return "Compliance";
  }
}

/// Material Symbols icon name of a tab.
string tabIcon(string tab) pure nothrow {
  switch (tab) {
    case "activities": return "list_alt";
    case "requests": return "person_search";
    case "breaches": return "warning";
    case "consents": return "how_to_reg";
    default: return "verified_user";
  }
}
