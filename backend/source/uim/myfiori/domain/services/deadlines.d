/// Statutory GDPR deadlines (Art. 12 (3) and Art. 33 (1)).
module uim.myfiori.domain.services.deadlines;

@safe:

import core.time : hours;
import std.datetime.date : AllowDayOverflow, Date;
import std.datetime.systime : SysTime;
import uim.myfiori.domain.types : DeadlinePolicy;

/**
 * Response deadline of a data subject request: one month after receipt (by default),
 * plus the extension period if extended. Month ends are clamped (31 Jan → 28/29 Feb).
 */
Date requestDueDate(Date receivedOn, bool extended, DeadlinePolicy p) pure nothrow {
  auto d = receivedOn;
  d.add!"months"(p.dsrResponseMonths + (extended ? p.dsrExtensionMonths : 0), AllowDayOverflow.no);
  return d;
}

/// Latest time for notifying the supervisory authority: detection + 72 h (by default).
SysTime breachDeadline(SysTime detectedAt, DeadlinePolicy p) {
  return detectedAt + p.breachNotificationHours.hours;
}

unittest {
  DeadlinePolicy p;
  assert(requestDueDate(Date(2026, 3, 15), false, p) == Date(2026, 4, 15));
  assert(requestDueDate(Date(2026, 3, 31), false, p) == Date(2026, 4, 30));
  assert(requestDueDate(Date(2026, 3, 15), true, p) == Date(2026, 6, 15));
}
