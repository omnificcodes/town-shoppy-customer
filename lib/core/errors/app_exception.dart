/// Base type for all handled application errors.
///
/// Every subtype carries a [message] that is already safe to show a
/// customer directly — never a raw Laravel exception, SQL error, or stack
/// trace (see [ApiExceptionMapper] for how backend error envelopes are
/// translated into these).
sealed class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType: $message (status: $statusCode)';
}

/// No connection, DNS failure, or request timeout — the request never
/// reached the backend (or its response never came back).
class NetworkException extends AppException {
  const NetworkException([super.message = "We couldn't connect. Check your internet connection and try again."]);
}

/// 401 — the session is invalid or expired. Callers must clear the stored
/// token and customer-scoped state and route to login (see section 38/65 of
/// the phase brief and [AuthController.logoutLocally]).
class UnauthenticatedException extends AppException {
  const UnauthenticatedException([super.message = 'Your session has expired. Please sign in again.']) : super(statusCode: 401);
}

/// 403 — authenticated, but not allowed to do this. Distinct from 401
/// deliberately (section 40: "403 does not accidentally log out unless
/// appropriate") — the session stays intact.
class ForbiddenException extends AppException {
  const ForbiddenException([super.message = "You don't have permission to do that."]) : super(statusCode: 403);
}

/// 404 — the resource doesn't exist or isn't visible to this account.
class NotFoundException extends AppException {
  const NotFoundException([super.message = "We couldn't find that."]) : super(statusCode: 404);
}

/// 409 — a state-transition or idempotency conflict (e.g. a purchase/
/// redemption already in a terminal state).
class ConflictException extends AppException {
  const ConflictException([super.message = 'That action conflicts with the current state.']) : super(statusCode: 409);
}

/// 422 — Laravel validation failure. [fieldErrors] mirrors the backend's
/// `errors` map (`{field: [messages]}`) exactly, so a form can highlight
/// the specific field without the caller needing to re-parse anything.
class ValidationAppException extends AppException {
  const ValidationAppException(super.message, this.fieldErrors) : super(statusCode: 422);

  final Map<String, List<String>> fieldErrors;

  /// First message for [field], if any — the common case for a single
  /// text field bound to one form control.
  String? firstErrorFor(String field) => fieldErrors[field]?.firstOrNull;
}

/// 429 — rate limited. [retryAfter] is populated from the `Retry-After`
/// header when the backend sends one (OTP request/verify, login, purchases,
/// redemptions, payments, and notification-actions all carry named
/// limiters — see AppServiceProvider).
class RateLimitedException extends AppException {
  const RateLimitedException(this.retryAfter, [super.message = 'Too many attempts. Please wait and try again.']) : super(statusCode: 429);

  final Duration? retryAfter;
}

/// 5xx — a genuine backend failure. Message is always the generic fallback
/// below, never `e.getMessage()` from the server, even if the backend's
/// `app.debug` happens to be on somewhere it shouldn't be.
class ServerException extends AppException {
  const ServerException([super.message = "Something went wrong on our end. Please try again."]) : super(statusCode: 500);
}

/// Anything that doesn't map cleanly to the above.
class UnknownAppException extends AppException {
  const UnknownAppException([super.message = 'Something unexpected happened.', int? statusCode]) : super(statusCode: statusCode);
}
