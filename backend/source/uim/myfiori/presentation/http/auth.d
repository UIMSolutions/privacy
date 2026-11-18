/// Request authentication / authorization helpers for HTTP adapters.
module uim.myfiori.presentation.http.auth;

@safe:

import std.string : indexOf, toLower;
import vibe.http.common : HTTPMethod;
import vibe.http.server : HTTPServerRequest;
import uim.myfiori.infrastructure.security;
import uim.myfiori.presentation.http.errors;

/// Authenticates the request and checks the scope; throws on failure.
Principal authorize(DAuthGuard guard, HTTPServerRequest req, string scope_) {
  auto principal = guard.authenticate(req.headers.get("Authorization", ""));
  if (!principal.hasScope(scope_))
    throw new ForbiddenException("Missing scope '" ~ scope_ ~ "'");
  return principal;
}

/**
 * Cross-site request protection for local mode. Without authentication any web page could
 * otherwise POST to http://127.0.0.1:8080 (e.g. /api/restore). Writing requests are rejected
 * when the browser reports a foreign Origin or a cross-site fetch. With XSUAA authentication
 * the bearer token (which browsers never attach automatically) already prevents CSRF.
 */
void ensureNotCrossSite(DAuthGuard guard, HTTPServerRequest req) @trusted {
  if (guard.enabled) return;
  if (req.method == HTTPMethod.GET || req.method == HTTPMethod.HEAD || req.method == HTTPMethod.OPTIONS) return;
  auto origin = req.headers.get("Origin", "");
  if (origin.length && origin != "null") {
    auto p = origin.indexOf("://");
    auto originHost = p >= 0 ? origin[p + 3 .. $] : origin;
    if (originHost.toLower != req.headers.get("Host", "").toLower)
      throw new ForbiddenException("Cross-site request rejected (Origin " ~ origin ~ ")");
  } else if (origin == "null" || req.headers.get("Sec-Fetch-Site", "") == "cross-site") {
    throw new ForbiddenException("Cross-site request rejected");
  }
}
