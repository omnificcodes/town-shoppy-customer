import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_error_mapper.dart';

/// Wraps [Dio] with the base configuration shared by every API call:
/// base URL from [Env], JSON headers, connect/receive timeouts, automatic
/// bearer-token injection from secure storage, and translation of every
/// failure into the app's [AppException] hierarchy before it ever reaches a
/// repository.
///
/// [onUnauthorized] is a mutable hook (not a constructor requirement) so the
/// auth layer can wire itself in without a circular provider dependency —
/// see `authControllerProvider`, which sets it once during initialization.
/// It fires on every 401, after the token has already been dropped from the
/// outgoing request pipeline for subsequent calls; the caller is
/// responsible for clearing storage and customer-scoped app state.
class ApiClient {
  ApiClient({required SecureStorageService secureStorage})
      : dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: AppConstants.networkConnectTimeout,
            receiveTimeout: AppConstants.networkReceiveTimeout,
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.read(AppConstants.secureStorageAuthTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: ApiErrorMapper.map(error),
            ),
          );
        },
      ),
    );
  }

  final Dio dio;

  void Function()? onUnauthorized;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(secureStorage: ref.watch(secureStorageServiceProvider));
});
