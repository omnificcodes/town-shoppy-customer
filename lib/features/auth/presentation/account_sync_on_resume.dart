import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// Re-reads the signed-in account whenever the app comes back to the
/// foreground -- a phone unlocked, the app switched back to, or (on web) the
/// browser tab shown again.
///
/// Returning is when the account is most likely to have changed somewhere
/// else: a business registered through the merchant web portal, in another
/// tab, or on another device, or approved/removed by a Super Admin. Without
/// this the app kept the account it signed in with until the next sign-in,
/// so an owner went on seeing "Register your business".
///
/// Throttled inside [AuthController.syncAccount], so flicking between
/// tabs does not fire a request each time.
class AccountSyncOnResume extends ConsumerStatefulWidget {
  const AccountSyncOnResume({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountSyncOnResume> createState() => _AccountSyncOnResumeState();
}

class _AccountSyncOnResumeState extends ConsumerState<AccountSyncOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onResume: () => ref.read(authControllerProvider.notifier).syncAccount());
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
