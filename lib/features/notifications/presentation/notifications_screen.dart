import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
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
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.value?.items.any((n) => n.isUnread) ?? false)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark all read',
              onPressed: () => ref.read(notificationsControllerProvider.notifier).markAllRead(),
            ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const LoadingSkeletonCard(),
          ),
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
              child: ListView.builder(
                controller: _scrollController,
                itemCount: data.items.length + (data.hasMore ? 1 : 0),
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
      ),
    );
  }
}
