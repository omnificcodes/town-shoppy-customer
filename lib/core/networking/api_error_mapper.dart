import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Translates a [DioException] into the app's own [AppException] hierarchy.
///
/// This is the single place that understands the backend's error envelope
/// (`{success:false, message, errors?}` — see `App\Http\Responses\ApiResponse`
/// and `bootstrap/app.php`'s exception renderers) so no repository or widget
/// ever touches a raw Dio/HTTP error directly.
class ApiErrorMapper {
  ApiErrorMapper._();

  static AppException map(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.cancel:
        return const UnknownAppException('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const NetworkException('Could not establish a secure connection.');
      case DioExceptionType.badResponse:
        return _mapResponse(error);
      case DioExceptionType.unknown:
        return const NetworkException();
    }
  }

  static AppException _mapResponse(DioException error) {
    final response = error.response;
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    final message = _extractMessage(body);

    switch (status) {
      case 401:
        return UnauthenticatedException(message ?? const UnauthenticatedException().message);
      case 403:
        return ForbiddenException(message ?? const ForbiddenException().message);
      case 404:
        return NotFoundException(message ?? const NotFoundException().message);
      case 409:
        return ConflictException(message ?? const ConflictException().message);
      case 422:
        // The backend's top-level `message` for a validation failure is
        // always the same generic "The given data was invalid." (see
        // bootstrap/app.php's ValidationException renderer) -- the actual,
        // specific reason (e.g. "An account already exists for this mobile
        // number.", "Invalid credentials.") lives only in `errors`. No
        // screen in this app does per-field server-error display -- every
        // screen just shows `.message` directly -- so prefer the first
        // field error here, once, for every caller, rather than the
        // generic fallback.
        final fieldErrors = _extractFieldErrors(body);
        final firstFieldMessage = fieldErrors.values.firstOrNull?.firstOrNull;
        return ValidationAppException(
          firstFieldMessage ?? message ?? 'The given data was invalid.',
          fieldErrors,
        );
      case 429:
        return RateLimitedException(_extractRetryAfter(response?.headers));
      default:
        if (status >= 500) return const ServerException();
        return UnknownAppException(message ?? 'Something unexpected happened.', status);
    }
  }

  static String? _extractMessage(dynamic body) {
    if (body is Map && body['message'] is String) return body['message'] as String;
    return null;
  }

  static Map<String, List<String>> _extractFieldErrors(dynamic body) {
    if (body is! Map || body['errors'] is! Map) return const {};

    final raw = body['errors'] as Map;
    return raw.map((key, value) {
      final messages = value is List ? value.map((e) => e.toString()).toList() : <String>[value.toString()];
      return MapEntry(key.toString(), messages);
    });
  }

  static Duration? _extractRetryAfter(Headers? headers) {
    final raw = headers?.value('retry-after');
    final seconds = raw != null ? int.tryParse(raw) : null;
    return seconds != null ? Duration(seconds: seconds) : null;
  }
}
