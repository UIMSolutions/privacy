/// Authorization guard used by HTTP adapters: maps requests to required XSUAA scopes.
module uim.myfiori.infrastructure.security.guard;

@safe:

import std.string : startsWith;
import uim.myfiori.infrastructure.configuration;
import uim.myfiori.infrastructure.security.jwt;

/// Scope needed for an HTTP method: reads need "Viewer", writes need "Editor".
string requiredScope(string method) pure nothrow {
  switch (method) {
    case "GET", "HEAD", "OPTIONS": return "Viewer";
    default: return "Editor";
  }
}

class DAuthGuard {
  private AppConfig _cfg;

  this(AppConfig cfg) { _cfg = cfg; }

  bool enabled() const { return _cfg.authEnabled; }

  /**
   * Authenticates an "Authorization" header value. Without authentication the local
   * principal (all scopes) is returned. Throws AuthenticationException on failure.
   */
  Principal authenticate(string authorizationHeader) {
    if (!_cfg.authEnabled) return localPrincipal;
    if (!authorizationHeader.startsWith("Bearer "))
      throw new AuthenticationException("Missing bearer token");
    if (_cfg.xsuaa.verificationKey.length == 0)
      throw new AuthenticationException("Authentication enabled but no XSUAA verification key configured");
    return validateToken(authorizationHeader["Bearer ".length .. $], _cfg.xsuaa.verificationKey, _cfg.xsuaa.xsAppName);
  }
}
