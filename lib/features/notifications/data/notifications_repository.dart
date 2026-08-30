import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../../core/networking/cursor_page.dart';
import 'models/app_notification.dart';

/// `GET/POST /notifications*` — strictly own-account (NotificationPolicy's
/// own docblock: no admin/global view exists at all, by design).
class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<CursorPage<AppNotification>> list({String? cursor}) async {
    try {
      final response = await _dio.get(
        '/notifications',
        queryParameters: {if (cursor != null) 'cursor': cursor},
      );
      final items = (ApiEnvelope.data(response) as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = ApiEnvelope.meta(response);
      return CursorPage(items: items, nextCursor: meta?['next_cursor'] as String?);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      return (ApiEnvelope.data(response) as Map<String, dynamic>)['unread_count'] as int;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<AppNotification> markRead(int id) async {
    try {
      final response = await _dio.post('/notifications/$id/read');
      return AppNotification.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<int> markAllRead() async {
    try {
      final response = await _dio.post('/notifications/read-all');
      return (ApiEnvelope.data(response) as Map<String, dynamic>)['marked_read'] as int;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider).dio);
});
