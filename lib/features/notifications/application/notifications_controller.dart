import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/app_notification.dart';
import '../data/notifications_repository.dart';
import 'unread_count_provider.dart';

class NotificationsListState {
  const NotificationsListState({required this.items, required this.nextCursor, this.isLoadingMore = false});

  final List<AppNotification> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  NotificationsListState copyWith({List<AppNotification>? items, String? nextCursor, bool clearCursor = false, bool? isLoadingMore}) {
    return NotificationsListState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class NotificationsController extends AsyncNotifier<NotificationsListState> {
  @override
  Future<NotificationsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(notificationsRepositoryProvider).list();
    return NotificationsListState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(notificationsRepositoryProvider).list(cursor: current.nextCursor);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // A load-more failure keeps the existing list intact — only the
      // trailing loading indicator drops, so the user can retry by
      // scrolling again rather than losing what already loaded.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> markRead(int id) async {
    final current = state.value;
    if (current == null) return;

    final wasUnread = current.items.firstWhere((n) => n.id == id, orElse: () => current.items.first).isUnread;

    final updated = await ref.read(notificationsRepositoryProvider).markRead(id);
    state = AsyncData(
      current.copyWith(items: [for (final n in current.items) if (n.id == id) updated else n]),
    );

    if (wasUnread) ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null) return;

    await ref.read(notificationsRepositoryProvider).markAllRead();
    final now = DateTime.now();
    state = AsyncData(
      current.copyWith(items: [for (final n in current.items) n.isUnread ? n.markedRead(now) : n]),
    );
    ref.invalidate(unreadNotificationCountProvider);
  }
}

final notificationsControllerProvider = AsyncNotifierProvider<NotificationsController, NotificationsListState>(
  NotificationsController.new,
);
