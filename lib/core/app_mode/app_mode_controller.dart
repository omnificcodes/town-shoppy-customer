import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';
import 'app_mode.dart';

/// The remembered [AppMode], plus whether it has been read from disk yet.
///
/// [loaded] exists so the router can tell "no choice saved" (send a
/// merchant account to the chooser) apart from "haven't looked yet" (keep
/// showing the splash) -- collapsing the two into a nullable would flash the
/// chooser on every cold start for a user who already picked Business.
class AppModeState {
  const AppModeState({required this.loaded, required this.mode});

  final bool loaded;
  final AppMode? mode;
}

/// Owns the persisted "last used mode" preference (product decision: the
/// chooser appears once, the app reopens in the last-used mode, and a
/// "Switch to ..." affordance lives in both modes' menus).
///
/// Stored in the same secure store as the auth token rather than a new
/// `shared_preferences` dependency -- it is one tiny string, the store is
/// already on every platform this app builds for, and it is cleared
/// together with the token on sign-out so the next account never inherits
/// the previous one's mode.
class AppModeController extends Notifier<AppModeState> {
  late final SecureStorageService _storage;

  @override
  AppModeState build() {
    _storage = ref.watch(secureStorageServiceProvider);
    _restore();
    return const AppModeState(loaded: false, mode: null);
  }

  Future<void> _restore() async {
    final raw = await _storage.read(AppConstants.secureStorageAppModeKey);
    // A select()/clear() that raced ahead of the disk read already knows
    // better than the stale stored value -- never overwrite it.
    if (state.loaded) return;
    state = AppModeState(loaded: true, mode: AppMode.tryParse(raw));
  }

  Future<void> select(AppMode mode) async {
    state = AppModeState(loaded: true, mode: mode);
    await _storage.write(AppConstants.secureStorageAppModeKey, mode.name);
  }

  /// Forgets the saved choice (sign-out). The next authenticated session
  /// starts from "no choice yet" so the chooser shows again for a merchant
  /// account -- and a plain customer account simply never sees it.
  Future<void> clear() async {
    state = const AppModeState(loaded: true, mode: null);
    await _storage.delete(AppConstants.secureStorageAppModeKey);
  }
}

final appModeControllerProvider = NotifierProvider<AppModeController, AppModeState>(AppModeController.new);
