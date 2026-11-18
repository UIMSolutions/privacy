/// Personal data breach (Art. 4 (12), Art. 33 / 34 GDPR).
module uim.myfiori.domain.entities.databreach;

@safe:

import std.datetime.systime : SysTime;
import std.typecons : Nullable;
import uim.myfiori.domain.entities.base;
import uim.myfiori.domain.enumerations;
import uim.myfiori.domain.exceptions;
import uim.myfiori.domain.services.deadlines;
import uim.myfiori.domain.types;

class DDataBreach : DEntity {
  private EntityId _projectId;
  private string _title;
  private string _description;
  private SysTime _detectedAt;
  private BreachSeverity _severity;
  private int _affectedSubjects;
  private string _dataCategories;
  private string _measures;                    // Art. 33 (3) d
  private BreachStatus _status;
  private Nullable!SysTime _reportedAt;        // notification to the supervisory authority
  private Nullable!SysTime _subjectsNotifiedAt; // communication to data subjects (Art. 34)

  this(EntityId id, EntityId projectId, string title, string description, SysTime detectedAt,
      BreachSeverity severity, int affectedSubjects, string dataCategories, string measures, BreachStatus status,
      Nullable!SysTime reportedAt, Nullable!SysTime subjectsNotifiedAt, SysTime createdAt, SysTime modifiedAt) {
    super(id, createdAt, modifiedAt);
    if (projectId.length == 0) throw new ValidationException("Data breach requires a project");
    _projectId = projectId;
    _title = requireText(title, "Breach title", 500);
    _description = limitText(description, "Description");
    _detectedAt = detectedAt.toUTC;
    _severity = severity;
    _affectedSubjects = checkAffected(affectedSubjects);
    _dataCategories = limitText(dataCategories, "Data categories");
    _measures = limitText(measures, "Measures");
    _status = status;
    _reportedAt = reportedAt;
    _subjectsNotifiedAt = subjectsNotifiedAt;
  }

  static DDataBreach create(EntityId id, EntityId projectId, string title, string description,
      Nullable!SysTime detectedAt, BreachSeverity severity, int affectedSubjects) {
    auto t = now;
    auto detected = detectedAt.isNull ? t : detectedAt.get.toUTC;
    if (detected > t) throw new ValidationException("Detection time must not be in the future");
    return new DDataBreach(id, projectId, title, description, detected, severity, affectedSubjects, "", "",
        BreachStatus.open, Nullable!SysTime.init, Nullable!SysTime.init, t, t);
  }

  EntityId projectId() const pure nothrow { return _projectId; }
  string title() const pure nothrow { return _title; }
  string description() const pure nothrow { return _description; }
  SysTime detectedAt() const pure nothrow { return _detectedAt; }
  BreachSeverity severity() const pure nothrow { return _severity; }
  int affectedSubjects() const pure nothrow { return _affectedSubjects; }
  string dataCategories() const pure nothrow { return _dataCategories; }
  string measures() const pure nothrow { return _measures; }
  BreachStatus status() const pure nothrow { return _status; }
  Nullable!SysTime reportedAt() const pure nothrow { return _reportedAt; }
  Nullable!SysTime subjectsNotifiedAt() const pure nothrow { return _subjectsNotifiedAt; }

  /// Art. 33 (1): notification required unless the breach is unlikely to result in a risk.
  bool authorityNotificationRequired() const pure nothrow { return _severity != BreachSeverity.low; }
  /// Art. 34 (1): communication to data subjects required for a likely high risk.
  bool subjectNotificationRequired() const pure nothrow { return _severity == BreachSeverity.high; }

  SysTime notificationDeadline(DeadlinePolicy p) const { return breachDeadline(_detectedAt, p); }

  /// Required notification not made (in time) – Art. 33 (1) sentence 2 requires reasons for delay.
  bool deadlineMissed(DeadlinePolicy p, SysTime at) const {
    if (!authorityNotificationRequired) return false;
    auto deadline = notificationDeadline(p);
    return _reportedAt.isNull ? at > deadline : _reportedAt.get > deadline;
  }

  /// Hours left until the authority deadline (negative when missed); 0 if reported or not required.
  long hoursLeft(DeadlinePolicy p, SysTime at) const {
    if (!authorityNotificationRequired || !_reportedAt.isNull) return 0;
    return (notificationDeadline(p) - at).total!"hours";
  }

  // ------------------------------------------------------------ business methods

  void retitle(string v) { ensureOpen; _title = requireText(v, "Breach title", 500); touch; }
  void describe(string v) { ensureOpen; _description = limitText(v, "Description"); touch; }
  void assess(BreachSeverity s, int affected) {
    ensureOpen;
    _severity = s;
    _affectedSubjects = checkAffected(affected);
    touch;
  }
  void documentData(string categories) { ensureOpen; _dataCategories = limitText(categories, "Data categories"); touch; }
  void documentMeasures(string v) { ensureOpen; _measures = limitText(v, "Measures"); touch; }

  /// Records the notification to the supervisory authority (Art. 33).
  void reportToAuthority(SysTime at) {
    ensureOpen;
    if (!_reportedAt.isNull) throw new ConflictException("Breach has already been reported to the authority");
    if (at.toUTC < _detectedAt) throw new ValidationException("Notification cannot precede the detection");
    _reportedAt = Nullable!SysTime(at.toUTC);
    _status = BreachStatus.reported;
    touch;
  }

  /// Records the communication to the affected data subjects (Art. 34).
  void notifySubjects(SysTime at) {
    ensureOpen;
    if (!_subjectsNotifiedAt.isNull) throw new ConflictException("Data subjects have already been notified");
    if (at.toUTC < _detectedAt) throw new ValidationException("Notification cannot precede the detection");
    _subjectsNotifiedAt = Nullable!SysTime(at.toUTC);
    touch;
  }

  /// Closes the case; all required notifications and the measures must be documented (Art. 33 (5)).
  void close() {
    ensureOpen;
    if (authorityNotificationRequired && _reportedAt.isNull)
      throw new ValidationException("Breach must be reported to the supervisory authority before closing (Art. 33)");
    if (subjectNotificationRequired && _subjectsNotifiedAt.isNull)
      throw new ValidationException("Data subjects must be notified before closing (Art. 34)");
    if (_measures.length == 0)
      throw new ValidationException("Document the measures taken before closing (Art. 33 (3) d, (5))");
    _status = BreachStatus.closed;
    touch;
  }

  private void ensureOpen() const {
    if (_status == BreachStatus.closed) throw new ConflictException("Breach '" ~ _title ~ "' is closed");
  }

  private static int checkAffected(int v) {
    if (v < 0) throw new ValidationException("Number of affected data subjects must not be negative");
    return v;
  }
}

unittest {
  import core.time : hours;
  import std.exception : assertThrown;
  DeadlinePolicy p;
  auto detected = now - 10.hours;
  auto b = DDataBreach.create("b1", "p1", "Lost laptop", "", Nullable!SysTime(detected), BreachSeverity.high, 120);
  assert(b.authorityNotificationRequired && b.subjectNotificationRequired);
  assert(!b.deadlineMissed(p, now) && b.hoursLeft(p, now) >= 61);
  assert(b.deadlineMissed(p, detected + 73.hours));
  assertThrown!ValidationException(b.close);
  b.reportToAuthority(now);
  b.notifySubjects(now);
  assertThrown!ValidationException(b.close);
  b.documentMeasures("remote wipe, password reset");
  b.close;
  assert(b.status == BreachStatus.closed);
  assertThrown!ConflictException(b.describe("x"));
}
