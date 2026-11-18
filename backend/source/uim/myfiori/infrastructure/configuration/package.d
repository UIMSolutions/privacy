/**
 * Type-safe application configuration.
 * Precedence: backend/config/default.json → environment variables (GDPR_*) → VCAP_SERVICES.
 */
module uim.myfiori.infrastructure.configuration;

@safe:

import std.conv : to;
import std.file : exists, readText;
import std.path : buildPath;
import std.process : environment;
import std.string : toLower;
import vibe.data.json;
import uim.myfiori.domain.types : DeadlinePolicy;

struct XsuaaConfig {
  string url;
  string clientId;
  string xsAppName = "gdpr";
  string verificationKey;   // PEM public key used to verify RS256 JWTs
}

struct AppConfig {
  string host = "127.0.0.1";
  ushort port = 8080;
  string logLevel = "info";
  string storage = "json";                 // json | memory
  string dataFile = "data/gdpr.json";
  string frontendDir = "../frontend";      // served under /ui/ for local development
  string publicDir = "public";
  bool authEnabled = false;
  int deadlineCheckMinutes = 60;           // 0 = background deadline monitor disabled
  int deadlineWarnDays = 7;                // DSRs due within N days are alerted
  string alertWebhook;                     // optional HTTP endpoint for deadline alerts (JSON POST)
  DeadlinePolicy policy;
  XsuaaConfig xsuaa;
}

/// Loads the configuration from `configDir`/default.json, the environment and VCAP_SERVICES.
AppConfig loadConfig(string configDir = "config") {
  AppConfig cfg;
  auto file = buildPath(configDir, "default.json");
  if (file.exists) applyJson(cfg, parseJsonString(readText(file), file));
  applyEnvironment(cfg, (string k) => environment.get(k, null));
  auto vcap = environment.get("VCAP_SERVICES", null);
  if (vcap.length) applyVcapServices(cfg, parseJsonString(vcap, "VCAP_SERVICES"));
  if (environment.get("VCAP_APPLICATION", null).length) cfg.host = "0.0.0.0";
  return cfg;
}

void applyJson(ref AppConfig cfg, Json j) {
  string s(string k, string d) { return j[k].type == Json.Type.string ? j[k].get!string : d; }
  int i(string k, int d) { return j[k].type == Json.Type.int_ ? j[k].get!long.to!int : d; }
  cfg.host = s("host", cfg.host);
  cfg.port = i("port", cfg.port).to!ushort;
  cfg.logLevel = s("logLevel", cfg.logLevel);
  cfg.storage = s("storage", cfg.storage);
  cfg.dataFile = s("dataFile", cfg.dataFile);
  cfg.frontendDir = s("frontendDir", cfg.frontendDir);
  cfg.publicDir = s("publicDir", cfg.publicDir);
  cfg.alertWebhook = s("alertWebhook", cfg.alertWebhook);
  if (j["authEnabled"].type == Json.Type.bool_) cfg.authEnabled = j["authEnabled"].get!bool;
  cfg.deadlineCheckMinutes = i("deadlineCheckMinutes", cfg.deadlineCheckMinutes);
  cfg.deadlineWarnDays = i("deadlineWarnDays", cfg.deadlineWarnDays);
  cfg.policy.dsrResponseMonths = i("dsrResponseMonths", cfg.policy.dsrResponseMonths);
  cfg.policy.dsrExtensionMonths = i("dsrExtensionMonths", cfg.policy.dsrExtensionMonths);
  cfg.policy.breachNotificationHours = i("breachNotificationHours", cfg.policy.breachNotificationHours);
  if (j["xsuaa"].type == Json.Type.object && j["xsuaa"]["xsappname"].type == Json.Type.string)
    cfg.xsuaa.xsAppName = j["xsuaa"]["xsappname"].get!string;
}

void applyEnvironment(ref AppConfig cfg, string delegate(string) @safe env) {
  if (auto v = env("GDPR_HOST")) cfg.host = v;
  if (auto v = env("GDPR_PORT")) cfg.port = v.to!ushort;
  if (auto v = env("PORT")) cfg.port = v.to!ushort;          // Cloud Foundry
  if (auto v = env("GDPR_LOG_LEVEL")) cfg.logLevel = v;
  if (auto v = env("GDPR_STORAGE")) cfg.storage = v;
  if (auto v = env("GDPR_DATA_FILE")) cfg.dataFile = v;
  if (auto v = env("GDPR_FRONTEND_DIR")) cfg.frontendDir = v;
  if (auto v = env("GDPR_PUBLIC_DIR")) cfg.publicDir = v;
  if (auto v = env("GDPR_AUTH")) cfg.authEnabled = v.toLower == "true" || v == "1";
  if (auto v = env("GDPR_DEADLINE_CHECK")) cfg.deadlineCheckMinutes = v.to!int;
  if (auto v = env("GDPR_DEADLINE_WARN_DAYS")) cfg.deadlineWarnDays = v.to!int;
  if (auto v = env("GDPR_ALERT_WEBHOOK")) cfg.alertWebhook = v;
}

/// Binds an XSUAA service instance; a bound XSUAA always enables authentication.
void applyVcapServices(ref AppConfig cfg, Json vcap) {
  if (vcap["xsuaa"].type != Json.Type.array || vcap["xsuaa"].length == 0) return;
  auto c = vcap["xsuaa"][0]["credentials"];
  string s(string k) { return c[k].type == Json.Type.string ? c[k].get!string : ""; }
  cfg.xsuaa.url = s("url");
  cfg.xsuaa.clientId = s("clientid");
  if (s("xsappname").length) cfg.xsuaa.xsAppName = s("xsappname");
  cfg.xsuaa.verificationKey = s("verificationkey");
  cfg.authEnabled = true;
}

unittest {
  AppConfig cfg;
  applyJson(cfg, parseJsonString(`{"port": 9001, "breachNotificationHours": 48}`));
  assert(cfg.port == 9001 && cfg.policy.breachNotificationHours == 48 && cfg.policy.dsrResponseMonths == 1);
  applyEnvironment(cfg, (string k) => k == "PORT" ? "9000" : k == "GDPR_AUTH" ? "true" : null);
  assert(cfg.port == 9000 && cfg.authEnabled);

  AppConfig c2;
  applyVcapServices(c2, parseJsonString(`{"xsuaa":[{"credentials":{"xsappname":"gdpr!t1","clientid":"sb-gdpr","verificationkey":"KEY","url":"https://uaa"}}]}`));
  assert(c2.authEnabled && c2.xsuaa.xsAppName == "gdpr!t1" && c2.xsuaa.verificationKey == "KEY");
}
