/// Common base of all aggregates: identity and audit timestamps.
module uim.myfiori.domain.entities.base;

@safe:

import std.datetime.systime : SysTime, Clock;
import uim.myfiori.domain.types;
import uim.myfiori.domain.exceptions;

abstract class DEntity {
  private EntityId _id;
  private SysTime _createdAt;
  private SysTime _modifiedAt;

  protected this(EntityId id, SysTime createdAt, SysTime modifiedAt) {
    if (id.length == 0)
      throw new ValidationException("Entity id must not be empty");
    _id = id;
    _createdAt = createdAt;
    _modifiedAt = modifiedAt;
  }

  EntityId id() const pure nothrow @nogc { return _id; }
  SysTime createdAt() const pure nothrow { return _createdAt; }
  SysTime modifiedAt() const pure nothrow { return _modifiedAt; }

  /// Must be called by every mutating business method.
  protected void touch() { _modifiedAt = Clock.currTime.toUTC; }
}
