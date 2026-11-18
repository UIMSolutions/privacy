/**
 * Business enumerations of the GDPR domain. Member names are the external
 * (OData / CLI / storage) representation.
 */
module uim.myfiori.domain.enumerations;

@safe:

import std.conv : to;
import std.traits : EnumMembers;
import uim.myfiori.domain.exceptions;

/// Life cycle of a GDPR (privacy) project.
enum ProjectStatus { planned, inProgress, completed, archived }

/// Legal basis of a processing activity (Art. 6 (1) lit. a–f GDPR).
enum LegalBasis { consent, contract, legalObligation, vitalInterests, publicTask, legitimateInterests }

/// Status of an entry in the record of processing activities (Art. 30).
enum ActivityStatus { draft, active, retired }

/// Risk to the rights and freedoms of natural persons.
enum RiskLevel { low, medium, high }

/// Data subject rights (Art. 15–21 GDPR).
enum RequestType { access, rectification, erasure, restriction, portability, objection }

/// Processing status of a data subject request.
enum RequestStatus { received, verified, inProgress, completed, rejected }

/// Severity of a personal data breach (Art. 33/34): low = "unlikely to result in a risk".
enum BreachSeverity { low, medium, high }

/// Processing status of a personal data breach.
enum BreachStatus { open, reported, closed }

/// Channel through which a consent was collected (proof of consent, Art. 7 (1)).
enum ConsentChannel { web, app, email, paper, phone, other }

/// Parses the external representation of an enum; throws ValidationException listing valid values.
E parseEnum(E)(string value, string field) if (is(E == enum)) {
  static foreach (m; EnumMembers!E)
    if (value == m.to!string) return m;
  throw new ValidationException("Invalid " ~ field ~ " '" ~ value ~ "' (allowed: " ~ enumValues!E ~ ")");
}

/// Comma separated list of all values.
string enumValues(E)() if (is(E == enum)) {
  string r;
  static foreach (i, m; EnumMembers!E) r ~= (i ? ", " : "") ~ m.to!string;
  return r;
}

/// All values as strings (for select boxes).
string[] enumNames(E)() if (is(E == enum)) {
  string[] r;
  static foreach (m; EnumMembers!E) r ~= m.to!string;
  return r;
}

/// Article of the GDPR that grants the right.
string article(RequestType t) pure nothrow {
  final switch (t) {
    case RequestType.access: return "Art. 15";
    case RequestType.rectification: return "Art. 16";
    case RequestType.erasure: return "Art. 17";
    case RequestType.restriction: return "Art. 18";
    case RequestType.portability: return "Art. 20";
    case RequestType.objection: return "Art. 21";
  }
}

/// Article of the GDPR for the legal basis.
string article(LegalBasis b) pure nothrow {
  final switch (b) {
    case LegalBasis.consent: return "Art. 6 (1) a";
    case LegalBasis.contract: return "Art. 6 (1) b";
    case LegalBasis.legalObligation: return "Art. 6 (1) c";
    case LegalBasis.vitalInterests: return "Art. 6 (1) d";
    case LegalBasis.publicTask: return "Art. 6 (1) e";
    case LegalBasis.legitimateInterests: return "Art. 6 (1) f";
  }
}

/// True for final request states.
bool isClosed(RequestStatus s) pure nothrow { return s == RequestStatus.completed || s == RequestStatus.rejected; }

unittest {
  import std.exception : assertThrown;
  assert(parseEnum!RequestType("erasure", "type") == RequestType.erasure);
  assertThrown!ValidationException(parseEnum!RequestType("delete", "type"));
  assert(enumValues!RiskLevel == "low, medium, high");
  assert(article(RequestType.portability) == "Art. 20");
}
