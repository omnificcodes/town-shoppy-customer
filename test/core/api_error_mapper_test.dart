import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/api_error_mapper.dart';

DioException _response(int status, {dynamic data, Headers? headers}) {
  final options = RequestOptions(path: '/test');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: data, headers: headers),
  );
}

void main() {
  group('ApiErrorMapper', () {
    test('maps connection timeout to NetworkException', () {
      final error = DioException(requestOptions: RequestOptions(path: '/test'), type: DioExceptionType.connectionTimeout);
      expect(ApiErrorMapper.map(error), isA<NetworkException>());
    });

    test('maps connection error to NetworkException', () {
      final error = DioException(requestOptions: RequestOptions(path: '/test'), type: DioExceptionType.connectionError);
      expect(ApiErrorMapper.map(error), isA<NetworkException>());
    });

    test('maps 401 to UnauthenticatedException', () {
      expect(ApiErrorMapper.map(_response(401)), isA<UnauthenticatedException>());
    });

    test('maps 403 to ForbiddenException', () {
      expect(ApiErrorMapper.map(_response(403)), isA<ForbiddenException>());
    });

    test('maps 404 to NotFoundException', () {
      expect(ApiErrorMapper.map(_response(404)), isA<NotFoundException>());
    });

    test('maps 409 to ConflictException', () {
      expect(ApiErrorMapper.map(_response(409)), isA<ConflictException>());
    });

    test('maps 422 to ValidationAppException and parses field errors', () {
      final error = _response(422, data: {
        'success': false,
        'message': 'The given data was invalid.',
        'errors': {
          'mobile_number': ['Please provide a valid mobile number.'],
        },
      });

      final mapped = ApiErrorMapper.map(error);
      expect(mapped, isA<ValidationAppException>());
      final validation = mapped as ValidationAppException;
      expect(validation.firstErrorFor('mobile_number'), 'Please provide a valid mobile number.');
      expect(validation.firstErrorFor('unknown_field'), isNull);
    });

    test('maps 429 to RateLimitedException and reads Retry-After header', () {
      final headers = Headers();
      headers.set('retry-after', '30');
      final mapped = ApiErrorMapper.map(_response(429, headers: headers));
      expect(mapped, isA<RateLimitedException>());
      expect((mapped as RateLimitedException).retryAfter, const Duration(seconds: 30));
    });

    test('maps 500 to ServerException with a generic message, never the raw body', () {
      final mapped = ApiErrorMapper.map(_response(500, data: {'message': 'SQLSTATE[HY000]: something internal'}));
      expect(mapped, isA<ServerException>());
      expect(mapped.message, isNot(contains('SQLSTATE')));
    });

    test('maps an unrecognized status to UnknownAppException', () {
      expect(ApiErrorMapper.map(_response(418)), isA<UnknownAppException>());
    });
  });
}
