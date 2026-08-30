import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/silver_wallet_balance.dart';
import '../data/wallet_repository.dart';

/// design-principles.md: a coin balance must never blank while refreshing
/// if a value is already known. [refresh] never sets `state` to
/// [AsyncLoading] — it keeps whatever the last successful [AsyncData] was
/// until the new result (or error) arrives, so the UI always has a value to
/// show; [walletRefreshingProvider] is the separate signal a widget uses to
/// render a small inline indicator during that window.
class WalletController extends AsyncNotifier<SilverWalletBalance> {
  @override
  Future<SilverWalletBalance> build() async {
    ref.watch(sessionEpochProvider);
    return ref.watch(walletRepositoryProvider).balance();
  }

  Future<void> refresh() async {
    ref.read(walletRefreshingProvider.notifier).set(true);
    try {
      final value = await ref.read(walletRepositoryProvider).balance();
      state = AsyncData(value);
    } catch (e, st) {
      // Only replace state with an error if there was nothing to show
      // before — otherwise keep the last-known balance visible.
      if (!state.hasValue) state = AsyncError(e, st);
    } finally {
      ref.read(walletRefreshingProvider.notifier).set(false);
    }
  }
}

final walletControllerProvider = AsyncNotifierProvider<WalletController, SilverWalletBalance>(WalletController.new);

class _WalletRefreshing extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final walletRefreshingProvider = NotifierProvider<_WalletRefreshing, bool>(_WalletRefreshing.new);
