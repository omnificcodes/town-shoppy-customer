import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Unwraps the `data`/`meta` fields of the backend's success envelope
/// (`App\Http\Responses\ApiResponse::success`) and converts a caught
/// [DioException] into the app's own [AppException] — the one place every
/// repository funnels through so no raw Dio type ever leaks past this layer.
class ApiEnvelope {
  ApiEnvelope._();

  static dynamic data(Response response) => response.data is Map ? response.data['data'] : response.data;

  static Map<String, dynamic>? meta(Response response) {
    final body = response.data;
    if (body is Map && body['meta'] is Map) {
      return Map<String, dynamic>.from(body['meta'] as Map);
    }
    return null;
  }

  /// Re-throws whatever [ApiErrorMapper] attached to [error] during the
  /// client's `onError` interceptor, falling back to a generic exception if
  /// something bypassed that path (defensive — should not normally happen).
  static Never rethrowAsAppException(DioException error) {
    final mapped = error.error;
    if (mapped is AppException) throw mapped;
    throw const UnknownAppException();
  }
}
