/**
 * Value objects and composite types of the GDPR domain:
 * identities, e-mail addresses, calendar dates and timestamps (ISO 8601).
 */
module uim.myfiori.domain.types;

@safe:

import std.datetime.date : Date, DateTimeException;
import std.datetime.systime : SysTime, Clock;
import std.regex : ctRegex, matchFirst;
import std.string : strip;
import std.typecons : Nullable;
import uim.myfiori.domain.exceptions;

alias EntityId = string;

/// Validated, normalised (trimmed) e-mail address. Empty addresses are allowed when `optional`.
string validateEmail(string value, string field, bool optional = false) {
  auto v = value.strip;
  if (v.length == 0) {
    if (optional) return v;
    throw new ValidationException(field ~ " must not be empty");
  }
  if (!matchFirst(v, ctRegex!(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)))
    throw new ValidationException(field ~ " '" ~ v ~ "' is not a valid e-mail address");
  return v;
}

/// Trims a mandatory text and checks its maximum length.
string requireText(string value, string field, size_t maxLength = 255) {
  auto v = value.strip;
  if (v.length == 0) throw new ValidationException(field ~ " must not be empty");
  return limitText(v, field, maxLength);
}

/// Trims an optional text and checks its maximum length.
string limitText(string value, string field, size_t maxLength = 4000) {
  auto v = value.strip;
  if (v.length > maxLength)
    throw new ValidationException(field ~ " must not exceed " ~ to_s(maxLength) ~ " characters");
  return v;
}

private string to_s(size_t v) { import std.conv : to; return v.to!string; }

/// Parses "YYYY-MM-DD"; an empty string yields null.
Nullable!Date parseDate(string value, string field) {
  auto v = value.strip;
  if (v.length == 0) return Nullable!Date.init;
  try return Nullable!Date(Date.fromISOExtString(v));
  catch (DateTimeException) throw new ValidationException(field ~ " '" ~ v ~ "' is not a date (YYYY-MM-DD)");
}

/// Parses an ISO 8601 timestamp ("2026-05-01T10:00:00Z") or a plain date (midnight UTC); empty → null.
Nullable!SysTime parseTimestamp(string value, string field) {
  import std.datetime.timezone : UTC;
  auto v = value.strip;
  if (v.length == 0) return Nullable!SysTime.init;
  try {
    if (v.length == 10) return Nullable!SysTime(SysTime(Date.fromISOExtString(v), UTC()));
    if (v.length == 16 && v[10] == 'T') v ~= ":00";   // HTML datetime-local (local time)
    return Nullable!SysTime(SysTime.fromISOExtString(v).toUTC);
  } catch (DateTimeException) {
    throw new ValidationException(field ~ " '" ~ v ~ "' is not an ISO 8601 timestamp");
  }
}

/// ISO date string or "" for null.
string isoDate(Nullable!Date d) { return d.isNull ? "" : d.get.toISOExtString; }

/// ISO timestamp (UTC, seconds precision) or "" for null.
string isoTimestamp(Nullable!SysTime t) { return t.isNull ? "" : isoTimestamp(t.get); }

/// ditto
string isoTimestamp(SysTime t) {
  import core.time : Duration;
  auto u = t.toUTC;
  u.fracSecs = Duration.zero;
  return u.toISOExtString;
}

/// Today's date (UTC).
Date today() { return cast(Date) Clock.currTime.toUTC; }

/// Current time (UTC).
SysTime now() { return Clock.currTime.toUTC; }

unittest {
  import std.exception : assertThrown;
  assert(validateEmail(" a@b.de ", "email") == "a@b.de");
  assertThrown!ValidationException(validateEmail("nope", "email"));
  assert(validateEmail("", "email", true) == "");
  assert(parseDate("2026-01-31", "d").get == Date(2026, 1, 31));
  assert(parseDate("", "d").isNull);
  assertThrown!ValidationException(parseDate("31.01.2026", "d"));
  assert(isoTimestamp(parseTimestamp("2026-05-01", "t")) == "2026-05-01T00:00:00Z");
  assert(isoTimestamp(parseTimestamp("2026-05-01T12:30:00+02:00", "t")) == "2026-05-01T10:30:00Z");
}

/**
 * Statutory deadlines. Defaults follow the GDPR: one month for answering a data
 * subject request, extendable by two further months (Art. 12 (3)); 72 hours for
 * notifying a personal data breach to the supervisory authority (Art. 33 (1)).
 */
struct DeadlinePolicy {
  int dsrResponseMonths = 1;
  int dsrExtensionMonths = 2;
  int breachNotificationHours = 72;
}
