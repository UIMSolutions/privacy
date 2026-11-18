/// Consent of a data subject (Art. 4 (11), Art. 7 GDPR) with proof and withdrawal.
module uim.myfiori.domain.entities.consent;

@safe:

import std.datetime.systime : SysTime;
import std.typecons : Nullable;
import uim.myfiori.domain.entities.base;
import uim.myfiori.domain.enumerations;
import uim.myfiori.domain.exceptions;
import uim.myfiori.domain.types;

class DConsent : DEntity {
  private EntityId _projectId;
  private EntityId _activityId;      // optional: processing activity based on Art. 6 (1) a
  private string _subjectEmail;
  private string _purpose;
  private string _version;           // version of the consent text shown
  private ConsentChannel _channel;
  private SysTime _givenAt;
  private Nullable!SysTime _withdrawnAt;

  this(EntityId id, EntityId projectId, EntityId activityId, string subjectEmail, string purpose, string textVersion,
      ConsentChannel channel, SysTime givenAt, Nullable!SysTime withdrawnAt, SysTime createdAt, SysTime modifiedAt) {
    super(id, createdAt, modifiedAt);
    if (projectId.length == 0) throw new ValidationException("Consent requires a project");
    _projectId = projectId;
    _activityId = activityId;
    _subjectEmail = validateEmail(subjectEmail, "Data subject e-mail");
    _purpose = requireText(purpose, "Consent purpose", 1000);
    _version = limitText(textVersion, "Consent text version", 50);
    _channel = channel;
    _givenAt = givenAt.toUTC;
    _withdrawnAt = withdrawnAt;
  }

  static DConsent give(EntityId id, EntityId projectId, EntityId activityId, string subjectEmail, string purpose,
      string textVersion, ConsentChannel channel, Nullable!SysTime givenAt) {
    auto t = now;
    auto given = givenAt.isNull ? t : givenAt.get.toUTC;
    if (given > t) throw new ValidationException("Consent date must not be in the future");
    return new DConsent(id, projectId, activityId, subjectEmail, purpose, textVersion, channel, given,
        Nullable!SysTime.init, t, t);
  }

  EntityId projectId() const pure nothrow { return _projectId; }
  EntityId activityId() const pure nothrow { return _activityId; }
  string subjectEmail() const pure nothrow { return _subjectEmail; }
  string purpose() const pure nothrow { return _purpose; }
  string textVersion() const pure nothrow { return _version; }
  ConsentChannel channel() const pure nothrow { return _channel; }
  SysTime givenAt() const pure nothrow { return _givenAt; }
  Nullable!SysTime withdrawnAt() const pure nothrow { return _withdrawnAt; }
  bool active() const pure nothrow { return _withdrawnAt.isNull; }

  /// Art. 7 (3): withdrawal at any time; withdrawn consents stay as proof but are immutable.
  void withdraw(SysTime at) {
    if (!active) throw new ConflictException("Consent has already been withdrawn");
    if (at.toUTC < _givenAt) throw new ValidationException("Withdrawal cannot precede the consent");
    _withdrawnAt = Nullable!SysTime(at.toUTC);
    touch;
  }

  void relateTo(EntityId activityId) { ensureActive; _activityId = activityId; touch; }
  void restatePurpose(string purpose, string textVersion) {
    ensureActive;
    _purpose = requireText(purpose, "Consent purpose", 1000);
    _version = limitText(textVersion, "Consent text version", 50);
    touch;
  }

  private void ensureActive() const {
    if (!active) throw new ConflictException("A withdrawn consent can no longer be changed");
  }
}

unittest {
  import std.exception : assertThrown;
  auto c = DConsent.give("c1", "p1", "", "a@b.de", "Newsletter", "v1", ConsentChannel.web, Nullable!SysTime.init);
  assert(c.active);
  c.withdraw(now);
  assert(!c.active);
  assertThrown!ConflictException(c.withdraw(now));
  assertThrown!ConflictException(c.restatePurpose("x", "v2"));
}
