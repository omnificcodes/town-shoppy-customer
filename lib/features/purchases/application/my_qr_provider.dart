import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customer_qr_repository.dart';

/// The customer's own identity QR token (Method 3, 3-way purchase
/// architecture) -- `AsyncNotifier` rather than a plain `FutureProvider`
/// since `regenerate()` needs to update the held value in place.
class MyQrController extends AsyncNotifier<String> {
  @override
  Future<String> build() => ref.read(customerQrRepositoryProvider).show();

  Future<void> regenerate() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(customerQrRepositoryProvider).regenerate());
  }
}

final myQrProvider = AsyncNotifierProvider<MyQrController, String>(MyQrController.new);
