import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/purchase.dart';
import '../data/purchases_repository.dart';

final recentPurchasesProvider = FutureProvider<List<Purchase>>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(purchasesRepositoryProvider).recent();
});
