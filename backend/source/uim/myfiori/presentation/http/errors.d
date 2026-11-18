/// Maps domain/security exceptions to HTTP status codes.
module uim.myfiori.presentation.http.errors;

@safe:

import vibe.http.status : HTTPStatus;
import uim.myfiori.domain.exceptions;
import uim.myfiori.infrastructure.security : AuthenticationException;

/// Thrown by adapters for authorization failures.
class ForbiddenException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow { super(msg, file, line); }
}

/// Thrown by adapters for malformed requests (bad JSON, bad query options).
class BadRequestException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow { super(msg, file, line); }
}

struct ErrorInfo {
  HTTPStatus status;
  string code;
}

ErrorInfo classify(Exception e) nothrow {
  if (cast(EntityNotFoundException) e) return ErrorInfo(HTTPStatus.notFound, "NotFound");
  if (cast(ValidationException) e) return ErrorInfo(HTTPStatus.badRequest, "ValidationFailed");
  if (cast(ConflictException) e) return ErrorInfo(HTTPStatus.conflict, "Conflict");
  if (cast(BadRequestException) e) return ErrorInfo(HTTPStatus.badRequest, "BadRequest");
  if (cast(AuthenticationException) e) return ErrorInfo(HTTPStatus.unauthorized, "Unauthorized");
  if (cast(ForbiddenException) e) return ErrorInfo(HTTPStatus.forbidden, "Forbidden");
  return ErrorInfo(HTTPStatus.internalServerError, "InternalError");
}
