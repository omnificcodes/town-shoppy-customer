import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/referrals/application/referral_summary_provider.dart';
import 'package:customer/features/referrals/data/models/referral_summary.dart';
import 'package:customer/features/referrals/presentation/referral_screen.dart';

import '../../helpers/responsive_test_helper.dart';

final _summary = ReferralSummary(
  referralCode: 'TOWNSHOPPYVERYLONGCODE2026',
  referralLink: 'https://townshoppy.example.com/join?ref=TOWNSHOPPYVERYLONGCODE2026&utm_source=share&utm_campaign=customer',
  qualifiedCount: 12,
  pendingCount: 3,
  bonusCouponsEarned: 4,
  milestoneReferralCount: 10,
  nextMilestoneReferralsRemaining: 8,
  referrals: [
    ReferralHistoryEntry(
      id: 1,
      referrerName: null,
      referredName: 'Venkataramanujachandrasekaran Padmanabhaswamy Iyengar',
      status: 'qualified',
      qualifiedAt: DateTime(2026, 1, 1),
      rewardCoinsReferrer: 100,
      rewardCoinsReferred: 100,
      bonusCouponIssued: true,
      createdAt: DateTime(2026, 1, 1),
    ),
  ],
  referredBy: ReferralHistoryEntry(
    id: 2,
    referrerName: 'A Very Long Referrer Display Name From Registration',
    referredName: null,
    status: 'pending',
    qualifiedAt: null,
    rewardCoinsReferrer: null,
    rewardCoinsReferred: null,
    bonusCouponIssued: false,
    createdAt: DateTime(2026, 1, 1),
  ),
);

Widget _wrap() {
  return ProviderScope(
    overrides: [referralSummaryProvider.overrideWith((ref) async => _summary)],
    child: MaterialApp(theme: AppTheme.light, home: const ReferralScreen()),
  );
}

void main() {
  testWidgets('ReferralScreen renders a long code/link/name without overflow at every mandated viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Your referral code'), findsOneWidget);
        expect(find.text('TOWNSHOPPYVERYLONGCODE2026'), findsOneWidget);
        expect(find.text('Qualified'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('Referred by'), findsOneWidget);
        expect(find.textContaining('Venkataramanujachandrasekaran'), findsOneWidget);
      },
    );
  });
}
