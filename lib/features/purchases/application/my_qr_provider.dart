import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customer_qr_repository.dart';

/// The customer's own identity QR token (Method 3, 3-way purchase
/// architecture) -- `AsyncNotifier` rather than a plain `FutureProvider`
/// since `regenerate()` needs to update the held value in place.
class MyQrController extends AsyncNotifier<String> {
  @override
  Future<String> build() => ref.read(customerQrRepositoryProvider).show();

  /// Replaces the held token with a freshly issued one. The current code
  /// stays on screen while the request is in flight (the button shows the
  /// loading state via [myQrRegeneratingProvider]) rather than the whole
  /// screen dropping to a skeleton -- the customer may be standing at a
  /// counter. Errors propagate to the caller so the screen can report them;
  /// the previously held token remains valid to display in that case.
  Future<void> regenerate() async {
    if (ref.read(myQrRegeneratingProvider)) return;

    ref.read(myQrRegeneratingProvider.notifier).set(true);
    try {
      final token = await ref.read(customerQrRepositoryProvider).regenerate();
      state = AsyncData(token);
    } finally {
      ref.read(myQrRegeneratingProvider.notifier).set(false);
    }
  }
}

final myQrProvider = AsyncNotifierProvider<MyQrController, String>(MyQrController.new);

class _MyQrRegenerating extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// True while [MyQrController.regenerate] is in flight -- same shape as the
/// wallet's `walletRefreshingProvider`, so the QR never blanks mid-refresh.
final myQrRegeneratingProvider = NotifierProvider<_MyQrRegenerating, bool>(_MyQrRegenerating.new);
