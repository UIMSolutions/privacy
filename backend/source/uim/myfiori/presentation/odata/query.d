/**
 * OData v4 system query options evaluated on JSON entity collections:
 * $filter (eq, ne, gt, ge, lt, le, and, or, not, contains, startswith, endswith, tolower, toupper),
 * $orderby, $skip, $top, $count, $select.
 */
module uim.myfiori.presentation.odata.query;

@safe:

import std.algorithm : canFind, map, min, sort, splitter;
import std.array : array;
import std.ascii : isAlphaNum, isDigit, isWhite;
import std.conv : to, ConvException;
import std.string : endsWith, indexOf, startsWith, strip, toLower, toUpper;
import vibe.data.json;
import uim.myfiori.presentation.http.errors : BadRequestException;

struct QueryOptions {
  string filter;
  string orderBy;
  string select;
  long skip = 0;
  long top = -1;
  bool count;
}

struct QueryResult {
  Json[] items;
  long count;     // number of matches before $skip/$top
}

/// Reads the system query options from (already decoded) request parameters.
QueryOptions parseQueryOptions(string delegate(string) @safe get) {
  QueryOptions o;
  o.filter = get("$filter");
  o.orderBy = get("$orderby");
  o.select = get("$select");
  try {
    if (auto v = get("$skip")) o.skip = v.to!long;
    if (auto v = get("$top")) o.top = v.to!long;
  } catch (ConvException) throw new BadRequestException("$skip and $top must be integers");
  if (o.skip < 0 || o.top < -1) throw new BadRequestException("$skip and $top must not be negative");
  if (auto v = get("$count")) {
    if (v != "true" && v != "false") throw new BadRequestException("$count must be true or false");
    o.count = v == "true";
  }
  return o;
}

QueryResult applyQuery(Json[] items, QueryOptions o, string key) {
  Json[] result = items;
  if (o.filter.strip.length) {
    auto expr = FilterParser(o.filter).parse;
    Json[] filtered;
    foreach (item; result) if (truthy(expr.eval(item))) filtered ~= item;
    result = filtered;
  }
  if (o.orderBy.strip.length) result = orderBy(result, o.orderBy);
  auto total = cast(long) result.length;
  auto from = min(o.skip, total);
  auto to_ = o.top < 0 ? total : min(from + o.top, total);
  result = result[cast(size_t) from .. cast(size_t) to_];
  if (o.select.strip.length) result = result.map!(i => selectFields(i, o.select, key)).array;
  return QueryResult(result, total);
}

/// Projects an entity onto the comma separated $select list (key always kept).
Json selectFields(Json item, string select, string key) @trusted {
  auto fields = select.splitter(',').map!(s => s.strip).array;
  if (fields.canFind("*")) return item;
  auto r = Json.emptyObject;
  foreach (string k, v; item)
    if (k == key || fields.canFind(k)) r[k] = v;
  return r;
}

private Json[] orderBy(Json[] items, string spec) {
  struct Key { string field; bool desc; }
  Key[] keys;
  foreach (part; spec.splitter(',')) {
    auto p = part.strip;
    bool desc;
    if (p.endsWith(" desc")) { desc = true; p = p[0 .. $ - 5].strip; }
    else if (p.endsWith(" asc")) p = p[0 .. $ - 4].strip;
    keys ~= Key(p, desc);
  }
  auto copy = items.dup;
  copy.sort!((a, b) {
    foreach (k; keys) {
      auto c = compareJson(a[k.field], b[k.field]);
      if (c != 0) return k.desc ? c > 0 : c < 0;
    }
    return false;
  });
  return copy;
}

/// Total order on JSON scalars; null/undefined sort first.
int compareJson(Json a, Json b) @trusted {
  bool aNull = a.type == Json.Type.null_ || a.type == Json.Type.undefined;
  bool bNull = b.type == Json.Type.null_ || b.type == Json.Type.undefined;
  if (aNull || bNull) return aNull == bNull ? 0 : (aNull ? -1 : 1);
  if (isNumber(a) && isNumber(b)) {
    auto x = toDouble(a), y = toDouble(b);
    return x < y ? -1 : (x > y ? 1 : 0);
  }
  if (a.type == Json.Type.bool_ && b.type == Json.Type.bool_)
    return a.get!bool == b.get!bool ? 0 : (a.get!bool ? 1 : -1);
  auto x = a.type == Json.Type.string ? a.get!string : a.toString;
  auto y = b.type == Json.Type.string ? b.get!string : b.toString;
  return x < y ? -1 : (x > y ? 1 : 0);
}

private bool isNumber(Json j) { return j.type == Json.Type.int_ || j.type == Json.Type.float_ || j.type == Json.Type.bigInt; }
private double toDouble(Json j) @trusted { return j.type == Json.Type.float_ ? j.get!double : j.to!long.to!double; }
private bool truthy(Json j) { return j.type == Json.Type.bool_ && j.get!bool; }

// ------------------------------------------------------------------ $filter

private interface Expr {
  Json eval(Json item);
}

private class Literal : Expr {
  Json value;
  this(Json v) { value = v; }
  Json eval(Json) { return value; }
}

private class Field : Expr {
  string name;
  this(string n) { name = n; }
  Json eval(Json item) { auto v = item[name]; return v.type == Json.Type.undefined ? Json(null) : v; }
}

private class Binary : Expr {
  string op;
  Expr lhs, rhs;
  this(string op, Expr l, Expr r) { this.op = op; lhs = l; rhs = r; }

  Json eval(Json item) {
    if (op == "and") return Json(truthy(lhs.eval(item)) && truthy(rhs.eval(item)));
    if (op == "or") return Json(truthy(lhs.eval(item)) || truthy(rhs.eval(item)));
    auto a = lhs.eval(item), b = rhs.eval(item);
    auto c = compareJson(a, b);
    bool anyNull = a.type == Json.Type.null_ || b.type == Json.Type.null_;
    switch (op) {
      case "eq": return Json(c == 0);
      case "ne": return Json(c != 0);
      case "gt": return Json(!anyNull && c > 0);
      case "ge": return Json(!anyNull && c >= 0);
      case "lt": return Json(!anyNull && c < 0);
      case "le": return Json(!anyNull && c <= 0);
      default: assert(false, op);
    }
  }
}

private class Not : Expr {
  Expr inner;
  this(Expr e) { inner = e; }
  Json eval(Json item) { return Json(!truthy(inner.eval(item))); }
}

private class Call : Expr {
  string name;
  Expr[] args;
  this(string n, Expr[] a) { name = n; args = a; }

  Json eval(Json item) {
    auto s(size_t i) {
      auto v = args[i].eval(item);
      return v.type == Json.Type.string ? v.get!string : (v.type == Json.Type.null_ ? "" : v.toString);
    }
    switch (name) {
      case "contains": return Json(s(0).toLower.indexOf(s(1).toLower) >= 0);
      case "startswith": return Json(s(0).startsWith(s(1)));
      case "endswith": return Json(s(0).endsWith(s(1)));
      case "tolower": return Json(s(0).toLower);
      case "toupper": return Json(s(0).toUpper);
      default: assert(false, name);
    }
  }
}

private struct FilterParser {
  string src;
  size_t pos;

  Expr parse() {
    auto e = parseOr();
    skipWs();
    if (pos < src.length) fail("unexpected '" ~ src[pos .. $] ~ "'");
    return e;
  }

  private Expr parseOr() {
    auto e = parseAnd();
    while (keyword("or")) e = new Binary("or", e, parseAnd());
    return e;
  }

  private Expr parseAnd() {
    auto e = parseUnary();
    while (keyword("and")) e = new Binary("and", e, parseUnary());
    return e;
  }

  private Expr parseUnary() {
    if (keyword("not")) return new Not(parseUnary());
    auto lhs = parsePrimary();
    foreach (op; ["eq", "ne", "ge", "gt", "le", "lt"])
      if (keyword(op)) return new Binary(op, lhs, parsePrimary());
    return lhs;
  }

  private Expr parsePrimary() {
    skipWs();
    if (pos >= src.length) fail("unexpected end of expression");
    auto c = src[pos];
    if (c == '(') {
      pos++;
      auto e = parseOr();
      expect(')');
      return e;
    }
    if (c == '\'') return new Literal(Json(parseString()));
    if (c.isDigit || c == '-') {
      auto start = pos++;
      while (pos < src.length && (src[pos].isDigit || src[pos] == '.')) pos++;
      auto num = src[start .. pos];
      try return new Literal(num.indexOf('.') >= 0 ? Json(num.to!double) : Json(num.to!long));
      catch (ConvException) fail("invalid number '" ~ num ~ "'");
    }
    auto ident = parseIdent();
    if (ident == "true") return new Literal(Json(true));
    if (ident == "false") return new Literal(Json(false));
    if (ident == "null") return new Literal(Json(null));
    skipWs();
    if (pos < src.length && src[pos] == '(') {
      if (!["contains", "startswith", "endswith", "tolower", "toupper"].canFind(ident))
        fail("unsupported function '" ~ ident ~ "'");
      pos++;
      Expr[] args = [parseOr()];
      skipWs();
      while (pos < src.length && src[pos] == ',') { pos++; args ~= parseOr(); skipWs(); }
      expect(')');
      auto arity = (ident == "tolower" || ident == "toupper") ? 1 : 2;
      if (args.length != arity) fail(ident ~ " expects " ~ arity.to!string ~ " argument(s)");
      return new Call(ident, args);
    }
    return new Field(ident);
  }

  private string parseString() {
    pos++; // opening quote
    string r;
    while (true) {
      if (pos >= src.length) fail("unterminated string literal");
      if (src[pos] == '\'') {
        if (pos + 1 < src.length && src[pos + 1] == '\'') { r ~= '\''; pos += 2; continue; }
        pos++;
        return r;
      }
      r ~= src[pos++];
    }
  }

  private string parseIdent() {
    skipWs();
    auto start = pos;
    while (pos < src.length && (src[pos].isAlphaNum || src[pos] == '_' || src[pos] == '/')) pos++;
    if (start == pos) fail("identifier expected at position " ~ pos.to!string);
    return src[start .. pos];
  }

  private bool keyword(string kw) {
    skipWs();
    auto end = pos + kw.length;
    if (end <= src.length && src[pos .. end] == kw && (end == src.length || !(src[end].isAlphaNum || src[end] == '_'))) {
      pos = end;
      return true;
    }
    return false;
  }

  private void expect(char c) {
    skipWs();
    if (pos >= src.length || src[pos] != c) fail("'" ~ c ~ "' expected");
    pos++;
  }

  private void skipWs() { while (pos < src.length && src[pos].isWhite) pos++; }

  private noreturn fail(string msg) { throw new BadRequestException("Invalid $filter: " ~ msg); }
}

unittest {
  Json[] items = [
    parseJsonString(`{"ID":"1","name":"Alpha","level":2,"ok":true}`),
    parseJsonString(`{"ID":"2","name":"beta","level":5,"ok":false}`),
    parseJsonString(`{"ID":"3","name":"Gamma O'Neil","level":3,"ok":true}`),
  ];
  string[string] p = ["$filter": "level gt 2 and ok eq true"];
  auto o = parseQueryOptions((string k) => k in p ? p[k] : null);
  auto r = applyQuery(items, o, "ID");
  assert(r.count == 1 && r.items[0]["ID"].get!string == "3");

  p = ["$filter": "contains(name,'ALP') or name eq 'Gamma O''Neil'", "$orderby": "level desc", "$count": "true", "$top": "1", "$select": "name"];
  o = parseQueryOptions((string k) => k in p ? p[k] : null);
  r = applyQuery(items, o, "ID");
  assert(r.count == 2 && r.items.length == 1);
  assert(r.items[0]["ID"].get!string == "3" && r.items[0]["level"].type == Json.Type.undefined);

  p = ["$filter": "not (ok eq true)"];
  o = parseQueryOptions((string k) => k in p ? p[k] : null);
  assert(applyQuery(items, o, "ID").items[0]["ID"].get!string == "2");
}
