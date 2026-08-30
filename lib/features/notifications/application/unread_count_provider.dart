import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/notifications_repository.dart';

/// Unread notification count, used for the bottom-nav badge and the
/// notifications screen's own header. Watches [sessionEpochProvider] first
/// so it's recomputed from scratch on logout/account switch — see that
/// provider's own docblock.
final unreadNotificationCountProvider = FutureProvider<int>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});
