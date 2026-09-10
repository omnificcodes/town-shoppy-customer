import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/notifications_controller.dart';
import 'notification_tile.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _loadMoreThreshold = 200.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(notificationsControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);

    return AppScaffold(
      title: 'Notifications',
      padded: false,
      actions: [
        if (state.value?.items.any((n) => n.isUnread) ?? false)
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all read',
            onPressed: () => ref.read(notificationsControllerProvider.notifier).markAllRead(),
          ),
      ],
      body: state.when(
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(notificationsControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message: "You'll see updates about purchases, redemptions, and rewards here.",
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
            // Full-bleed rows separated by hairlines (an inbox), not cards:
            // read rows on white need the divider to stay distinguishable.
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: data.items.length + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1, indent: AppSpacing.page + AppSize.avatarMd + AppSpacing.smd),
              itemBuilder: (context, index) {
                if (index >= data.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final notification = data.items[index];
                return NotificationTile(
                  notification: notification,
                  onTap: () {
                    if (notification.isUnread) {
                      ref.read(notificationsControllerProvider.notifier).markRead(notification.id);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
