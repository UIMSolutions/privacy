/// Data subject request (DSR): exercise of a data subject right (Art. 15–21 GDPR).
module uim.myfiori.domain.entities.datasubjectrequest;

@safe:

import std.datetime.date : Date;
import std.datetime.systime : SysTime;
import std.typecons : Nullable;
import uim.myfiori.domain.entities.base;
import uim.myfiori.domain.enumerations;
import uim.myfiori.domain.exceptions;
import uim.myfiori.domain.services.deadlines;
import uim.myfiori.domain.types;

class DDataSubjectRequest : DEntity {
  private EntityId _projectId;
  private RequestType _type;
  private string _subjectName;
  private string _subjectEmail;
  private string _description;
  private Date _receivedOn;
  private bool _extended;
  private string _extensionReason;
  private RequestStatus _status;
  private string _resolution;
  private Nullable!Date _closedOn;

  this(EntityId id, EntityId projectId, RequestType type, string subjectName, string subjectEmail,
      string description, Date receivedOn, bool extended, string extensionReason, RequestStatus status,
      string resolution, Nullable!Date closedOn, SysTime createdAt, SysTime modifiedAt) {
    super(id, createdAt, modifiedAt);
    if (projectId.length == 0) throw new ValidationException("Data subject request requires a project");
    _projectId = projectId;
    _type = type;
    _subjectName = requireText(subjectName, "Data subject name");
    _subjectEmail = validateEmail(subjectEmail, "Data subject e-mail", true);
    _description = limitText(description, "Description");
    _receivedOn = receivedOn;
    _extended = extended;
    _extensionReason = limitText(extensionReason, "Extension reason");
    _status = status;
    _resolution = limitText(resolution, "Resolution");
    _closedOn = closedOn;
    if (_extended && _extensionReason.length == 0)
      throw new ValidationException("An extended request requires a reason (Art. 12 (3))");
  }

  static DDataSubjectRequest create(EntityId id, EntityId projectId, RequestType type, string subjectName,
      string subjectEmail, string description, Nullable!Date receivedOn) {
    auto t = now;
    if (!receivedOn.isNull && receivedOn.get > today)
      throw new ValidationException("Received date must not be in the future");
    return new DDataSubjectRequest(id, projectId, type, subjectName, subjectEmail, description,
        receivedOn.isNull ? today : receivedOn.get, false, "", RequestStatus.received, "", Nullable!Date.init, t, t);
  }

  EntityId projectId() const pure nothrow { return _projectId; }
  RequestType type() const pure nothrow { return _type; }
  string subjectName() const pure nothrow { return _subjectName; }
  string subjectEmail() const pure nothrow { return _subjectEmail; }
  string description() const pure nothrow { return _description; }
  Date receivedOn() const pure nothrow { return _receivedOn; }
  bool extended() const pure nothrow { return _extended; }
  string extensionReason() const pure nothrow { return _extensionReason; }
  RequestStatus status() const pure nothrow { return _status; }
  string resolution() const pure nothrow { return _resolution; }
  Nullable!Date closedOn() const pure nothrow { return _closedOn; }
  bool closed() const pure nothrow { return isClosed(_status); }

  /// Statutory response deadline (Art. 12 (3)).
  Date dueDate(DeadlinePolicy p) const { return requestDueDate(_receivedOn, _extended, p); }

  /// Open and past the deadline on `day`.
  bool overdue(DeadlinePolicy p, Date day) const { return !closed && day > dueDate(p); }

  /// Days until the deadline (negative when overdue); 0 for closed requests.
  long daysLeft(DeadlinePolicy p, Date day) const { return closed ? 0 : (dueDate(p) - day).total!"days"; }

  // ------------------------------------------------------------ business methods

  void correctSubject(string name, string email) {
    ensureOpen;
    _subjectName = requireText(name, "Data subject name");
    _subjectEmail = validateEmail(email, "Data subject e-mail", true);
    touch;
  }

  void describe(string v) { ensureOpen; _description = limitText(v, "Description"); touch; }

  /// Extends the deadline by the policy's extension period; only once and with a reason.
  void extend(string reason) {
    ensureOpen;
    if (_extended) throw new ConflictException("The deadline of this request has already been extended");
    auto r = limitText(reason, "Extension reason");
    if (r.length == 0) throw new ValidationException("An extension requires a reason (Art. 12 (3))");
    _extended = true;
    _extensionReason = r;
    touch;
  }

  /**
   * Moves the request forward: received → verified → inProgress → completed,
   * or rejects it from any open state. Closing requires a documented resolution.
   */
  void advance(RequestStatus target, string resolution = "") {
    ensureOpen;
    if (target == _status) {   // only the resolution note changes
      if (resolution.length) { _resolution = limitText(resolution, "Resolution"); touch; }
      return;
    }
    if (target == RequestStatus.received || (!isClosed(target) && target < _status))
      throw new ConflictException("Request status cannot go back from " ~ statusName(_status) ~ " to " ~ statusName(target));
    if (resolution.length) _resolution = limitText(resolution, "Resolution");
    if (isClosed(target)) {
      if (_resolution.length == 0)
        throw new ValidationException("Closing a request requires a resolution (what was done / reason for rejection)");
      _closedOn = Nullable!Date(today);
    }
    _status = target;
    touch;
  }

  private void ensureOpen() const {
    if (closed) throw new ConflictException("Request is " ~ statusName(_status) ~ " and can no longer be changed");
  }

  private static string statusName(RequestStatus s) { import std.conv : to; return s.to!string; }
}

unittest {
  import std.exception : assertThrown;
  DeadlinePolicy p;
  auto r = DDataSubjectRequest.create("r1", "p1", RequestType.access, "Max", "max@example.org", "",
      Nullable!Date(Date(2026, 1, 31)));
  assert(r.dueDate(p) == Date(2026, 2, 28));
  assert(r.overdue(p, Date(2026, 3, 1)));
  r.extend("complex request");
  assert(r.dueDate(p) == Date(2026, 4, 30));
  assertThrown!ConflictException(r.extend("again"));
  r.advance(RequestStatus.inProgress);
  assertThrown!ConflictException(r.advance(RequestStatus.verified));
  assertThrown!ValidationException(r.advance(RequestStatus.completed));
  r.advance(RequestStatus.completed, "copy of data sent");
  assert(r.closed && !r.closedOn.isNull && !r.overdue(p, Date(2027, 1, 1)));
  assertThrown!ConflictException(r.describe("x"));
}
