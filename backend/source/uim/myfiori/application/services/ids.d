/// Identity generation for new aggregates.
module uim.myfiori.application.services.ids;

@safe:

import std.regex : ctRegex, matchFirst;
import std.uuid : randomUUID;
import uim.myfiori.domain.exceptions;

/**
 * Returns `requested` if given (import with stable ids) or a fresh UUID.
 * Requested ids must be safe identifiers and must not exist yet.
 */
string newId(string requested, bool delegate(string) @safe exists) {
  if (requested.length == 0) return randomUUID.toString;
  if (!matchFirst(requested, ctRegex!(`^[A-Za-z0-9][A-Za-z0-9_.\-]{0,63}$`)))
    throw new ValidationException("Invalid id '" ~ requested ~ "' (letters, digits, '-', '_', '.'; max. 64)");
  if (exists(requested))
    throw new ConflictException("An entity with id '" ~ requested ~ "' already exists");
  return requested;
}

unittest {
  assert(newId("", (string) => false).length == 36);
  assert(newId("abc-1", (string) => false) == "abc-1");
  import std.exception : assertThrown;
  assertThrown!ValidationException(newId("../x", (string) => false));
  assertThrown!ConflictException(newId("abc", (string) => true));
}
