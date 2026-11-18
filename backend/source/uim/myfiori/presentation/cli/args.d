/// Minimal argument parser: positional arguments plus "--key value" / "--key=value" / "--flag".
module uim.myfiori.presentation.cli.args;

@safe:

import std.string : indexOf, startsWith;
import uim.myfiori.presentation.http.errors : BadRequestException;

/// Options that never take a value.
immutable string[] flagOptions = ["json", "help", "memory", "yes", "special-categories", "large-scale", "systematic-monitoring", "automated-decisions", "third-country-transfer", "dpia-completed"];

struct CliArgs {
  string[] positional;
  string[string] options;

  bool flag(string name) const { return (name in options) !is null; }

  string opt(string name, string fallback = "") const {
    if (auto v = name in options) return *v;
    return fallback;
  }

  string required(string name) const {
    if (auto v = name in options) if ((*v).length) return *v;
    throw new BadRequestException("Option --" ~ name ~ " is required");
  }

  string arg(size_t i, string what) const {
    if (i < positional.length) return positional[i];
    throw new BadRequestException("Missing argument: " ~ what);
  }
}

CliArgs parseArgs(string[] raw) {
  import std.algorithm : canFind;
  CliArgs a;
  for (size_t i = 0; i < raw.length; i++) {
    auto s = raw[i];
    if (s == "--") { a.positional ~= raw[i + 1 .. $]; break; }
    if (s.startsWith("--")) {
      auto body_ = s[2 .. $];
      auto eq = body_.indexOf('=');
      if (eq >= 0) a.options[body_[0 .. eq]] = body_[eq + 1 .. $];
      else if (flagOptions.canFind(body_) || i + 1 >= raw.length || raw[i + 1].startsWith("--")) a.options[body_] = "true";
      else a.options[body_] = raw[++i];
    } else a.positional ~= s;
  }
  return a;
}

unittest {
  auto a = parseArgs(["project", "create", "--name", "GDPR 2026", "--json", "--status=planned"]);
  assert(a.positional == ["project", "create"]);
  assert(a.opt("name") == "GDPR 2026" && a.flag("json") && a.opt("status") == "planned");
}
