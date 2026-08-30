import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/features/referrals/application/referral_summary_provider.dart';
import 'package:customer/features/referrals/data/models/referral_summary.dart';
import 'package:customer/features/referrals/data/referrals_repository.dart';

class FakeReferralsRepository implements ReferralsRepository {
  FakeReferralsRepository({this.summary, this.error});

  final ReferralSummary? summary;
  final AppException? error;

  @override
  Future<ReferralSummary> me() async {
    if (error != null) throw error!;
    return summary!;
  }
}

void main() {
  test('referralSummaryProvider surfaces the loaded summary', () async {
    const summary = ReferralSummary(
      referralCode: 'ABC123',
      referralLink: 'https://townshoppy.example/r/ABC123',
      qualifiedCount: 1,
      pendingCount: 0,
      bonusCouponsEarned: 0,
      milestoneReferralCount: 5,
      nextMilestoneReferralsRemaining: 4,
      referrals: [],
      referredBy: null,
    );
    final container = ProviderContainer(
      overrides: [referralsRepositoryProvider.overrideWithValue(FakeReferralsRepository(summary: summary))],
    );
    addTearDown(container.dispose);

    final result = await container.read(referralSummaryProvider.future);

    expect(result.referralCode, 'ABC123');
    expect(result.qualifiedCount, 1);
  });

  test('referralSummaryProvider surfaces a backend error', () async {
    final container = ProviderContainer(
      overrides: [referralsRepositoryProvider.overrideWithValue(FakeReferralsRepository(error: const ServerException()))],
    );
    addTearDown(container.dispose);

    // See the identical polling loop in `purchase_detail_provider_test.dart`
    // — Riverpod 3.3.2 keeps auto-retrying a failed build rather than
    // settling into a plain `AsyncError`.
    var state = container.read(referralSummaryProvider);
    for (var i = 0; i < 50 && !state.hasError; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = container.read(referralSummaryProvider);
    }

    expect(state.hasError, isTrue);
    expect(state.error, isA<ServerException>());
  });
}
