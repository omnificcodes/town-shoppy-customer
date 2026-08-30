import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/referral_summary.dart';
import '../data/referrals_repository.dart';

final referralSummaryProvider = FutureProvider<ReferralSummary>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(referralsRepositoryProvider).me();
});
