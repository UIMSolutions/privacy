/**
 * Generic binding of input DTOs from JSON bodies (OData) or string key/value
 * sources (HTML forms, CLI options). Supported field types: string, int, bool
 * and their Nullable variants (absent → null = "unchanged").
 */
module uim.myfiori.presentation.http.binding;

@safe:

import std.conv : to, ConvException;
import std.string : strip, toLower;
import std.traits : FieldNameTuple;
import std.typecons : Nullable;
import vibe.data.json;
import uim.myfiori.presentation.http.errors : BadRequestException;

/// Binds T from a JSON object; unknown properties are ignored, wrong types rejected.
T bindJson(T)(Json body_) @trusted {
  T result;
  static foreach (name; FieldNameTuple!T) {{
    alias F = typeof(__traits(getMember, result, name));
    auto v = body_[name];
    if (v.type != Json.Type.undefined) {
      static if (is(F == Nullable!U, U)) {
        if (v.type == Json.Type.null_) {
          static if (is(U == string)) __traits(getMember, result, name) = F("");
        } else __traits(getMember, result, name) = F(jsonValue!U(v, name));
      } else if (v.type != Json.Type.null_) {
        __traits(getMember, result, name) = jsonValue!F(v, name);
      }
    }
  }}
  return result;
}

private U jsonValue(U)(Json v, string name) @trusted {
  static if (is(U == string)) {
    if (v.type != Json.Type.string) throw new BadRequestException("Property '" ~ name ~ "' must be a string");
    return v.get!string;
  } else static if (is(U == bool)) {
    if (v.type != Json.Type.bool_) throw new BadRequestException("Property '" ~ name ~ "' must be a boolean");
    return v.get!bool;
  } else static if (is(U == int)) {
    if (v.type != Json.Type.int_) throw new BadRequestException("Property '" ~ name ~ "' must be an integer");
    return v.get!long.to!int;
  } else static assert(false, "Unsupported field type " ~ U.stringof);
}

/**
 * Binds T from a string source (`get` returns null when the key is absent).
 * `key` maps field names to source keys (e.g. camelCase → kebab-case for the CLI).
 */
T bindStrings(T)(string delegate(string) @safe get, string function(string) @safe key = &identity) {
  T result;
  static foreach (name; FieldNameTuple!T) {{
    alias F = typeof(__traits(getMember, result, name));
    auto raw = get(key(name));
    if (raw !is null) {
      static if (is(F == Nullable!U, U)) __traits(getMember, result, name) = F(stringValue!U(raw, key(name)));
      else __traits(getMember, result, name) = stringValue!F(raw, key(name));
    }
  }}
  return result;
}

string identity(string s) @safe pure nothrow { return s; }

/// "legalBasis" → "legal-basis"
string kebab(string s) @safe pure nothrow {
  string r;
  foreach (c; s) {
    if (c >= 'A' && c <= 'Z') { r ~= '-'; r ~= cast(char) (c + 32); }
    else r ~= c;
  }
  return r;
}

/// Parses a boolean from forms / CLI: true|false|yes|no|on|off|1|0.
bool parseBool(string raw, string name) {
  switch (raw.strip.toLower) {
    case "true", "yes", "on", "1", "": return true;      // "" = bare CLI flag / checked box without value
    case "false", "no", "off", "0": return false;
    default: throw new BadRequestException("'" ~ raw ~ "' is not a boolean for " ~ name);
  }
}

private U stringValue(U)(string raw, string name) {
  static if (is(U == string)) return raw;
  else static if (is(U == bool)) return parseBool(raw, name);
  else static if (is(U == int)) {
    try return raw.strip.to!int;
    catch (ConvException) throw new BadRequestException("'" ~ raw ~ "' is not a number for " ~ name);
  } else static assert(false, "Unsupported field type " ~ U.stringof);
}

unittest {
  static struct S { string a; int n; bool b; Nullable!string c; Nullable!bool d; Nullable!int e; }
  auto s = bindJson!S(parseJsonString(`{"a":"x","n":3,"b":true,"c":null,"e":7}`));
  assert(s.a == "x" && s.n == 3 && s.b && s.c.get == "" && s.d.isNull && s.e.get == 7);
  string[string] m = ["a": "y", "b": "on", "d": "false", "n": "5"];
  auto t = bindStrings!S((string k) => k in m ? m[k] : null);
  assert(t.a == "y" && t.b && !t.d.get && t.n == 5 && t.c.isNull);
  assert(kebab("legalBasis") == "legal-basis");
  import std.exception : assertThrown;
  assertThrown!BadRequestException(bindJson!S(parseJsonString(`{"n":"3"}`)));
}
