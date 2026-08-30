import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/redemption.dart';
import '../data/redemptions_repository.dart';

final redemptionDetailProvider = FutureProvider.family<Redemption, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(redemptionsRepositoryProvider).show(id);
});
