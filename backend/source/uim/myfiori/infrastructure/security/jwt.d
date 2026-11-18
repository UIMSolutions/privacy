/**
 * Validation of XSUAA access tokens (RS256-signed JWTs) forwarded by the approuter.
 * Signature verification uses OpenSSL's EVP API with the XSUAA verification key.
 */
module uim.myfiori.infrastructure.security.jwt;

import std.algorithm : canFind, map;
import std.array : array;
import std.base64 : Base64URLNoPadding, Base64Exception;
import std.datetime.systime : Clock;
import std.string : split, startsWith;
import vibe.data.json;

import deimos.openssl.bio;
import deimos.openssl.evp;
import deimos.openssl.pem;

class AuthenticationException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow { super(msg, file, line); }
}

/// Authenticated principal derived from a validated token.
struct Principal {
  string userName;
  string email;
  string[] scopes;      // local scope names without xsappname prefix (e.g. "Viewer")

  bool hasScope(string scope_) const @safe pure nothrow { return scopes.canFind(scope_); }
}

/// Anonymous principal with all scopes (authentication disabled, local development / CLI).
Principal localPrincipal() @safe {
  return Principal("local", "", ["Viewer", "Editor", "Admin"]);
}

/// Validates the token and returns its principal; throws AuthenticationException.
Principal validateToken(string token, string verificationKey, string xsAppName) @trusted {
  auto parts = token.split(".");
  if (parts.length != 3) throw new AuthenticationException("Malformed token");

  auto header = decodeJsonPart(parts[0]);
  if (header["alg"].opt!string != "RS256") throw new AuthenticationException("Unsupported token algorithm");

  ubyte[] signature;
  try signature = Base64URLNoPadding.decode(parts[2]);
  catch (Base64Exception) throw new AuthenticationException("Malformed token signature");
  if (!verifyRs256(cast(const(ubyte)[]) (parts[0] ~ "." ~ parts[1]), signature, verificationKey))
    throw new AuthenticationException("Invalid token signature");

  auto claims = decodeJsonPart(parts[1]);
  auto exp = claims["exp"];
  if (exp.type != Json.Type.int_ || exp.get!long < Clock.currTime.toUnixTime)
    throw new AuthenticationException("Token expired");

  Principal p;
  p.userName = claims["user_name"].opt!string(claims["client_id"].opt!string);
  p.email = claims["email"].opt!string;
  auto prefix = xsAppName ~ ".";
  if (claims["scope"].type == Json.Type.array)
    foreach (s; claims["scope"])
      if (s.type == Json.Type.string && s.get!string.startsWith(prefix))
        p.scopes ~= s.get!string[prefix.length .. $];
  return p;
}

private Json decodeJsonPart(string part) @trusted {
  try return parseJsonString(cast(string) Base64URLNoPadding.decode(part));
  catch (Exception) throw new AuthenticationException("Malformed token");
}

/// RSASSA-PKCS1-v1_5 with SHA-256 using a PEM encoded public key.
bool verifyRs256(const(ubyte)[] data, const(ubyte)[] signature, string pemKey) @trusted {
  auto pem = normalizePem(pemKey);
  auto bio = BIO_new_mem_buf(cast(void*) pem.ptr, cast(int) pem.length);
  if (bio is null) return false;
  scope (exit) BIO_free(bio);
  auto key = PEM_read_bio_PUBKEY(bio, null, null, null);
  if (key is null) return false;
  scope (exit) EVP_PKEY_free(key);
  auto ctx = EVP_MD_CTX_new();
  if (ctx is null) return false;
  scope (exit) EVP_MD_CTX_free(ctx);
  if (EVP_DigestVerifyInit(ctx, null, EVP_sha256(), null, key) != 1) return false;
  if (EVP_DigestVerifyUpdate(ctx, data.ptr, data.length) != 1) return false;
  return EVP_DigestVerifyFinal(ctx, cast(ubyte*) signature.ptr, signature.length) == 1;
}

/// XSUAA delivers the key sometimes without line breaks; OpenSSL needs 64-char lines.
private string normalizePem(string key) @safe {
  import std.string : replace, strip;
  enum head = "-----BEGIN PUBLIC KEY-----", tail = "-----END PUBLIC KEY-----";
  auto body_ = key.replace(head, "").replace(tail, "").replace("\\n", "").replace("\n", "").replace("\r", "").strip;
  string result = head ~ "\n";
  for (size_t i = 0; i < body_.length; i += 64)
    result ~= body_[i .. (i + 64 < body_.length ? i + 64 : body_.length)] ~ "\n";
  return result ~ tail ~ "\n";
}
