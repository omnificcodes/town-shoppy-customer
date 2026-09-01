import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/coupons_repository.dart';
import '../data/models/coupon.dart';

final couponDetailProvider = FutureProvider.family<Coupon, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(couponsRepositoryProvider).show(id);
});
