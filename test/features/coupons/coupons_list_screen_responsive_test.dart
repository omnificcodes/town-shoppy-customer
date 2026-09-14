import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/coupons/application/coupons_list_controller.dart';
import 'package:customer/features/coupons/data/coupons_repository.dart';
import 'package:customer/features/coupons/data/models/coupon.dart';
import 'package:customer/features/coupons/presentation/coupons_list_screen.dart';

import '../../helpers/responsive_test_helper.dart';

final _active = Coupon(
  id: 1,
  code: 'D8QMVDZ7KDKXLONGCODE',
  status: 'active',
  sourceType: 'purchase',
  eligibilities: const [
    CouponEligibility(cadence: 'weekly', status: 'active'),
    CouponEligibility(cadence: 'monthly', status: 'active'),
    CouponEligibility(cadence: 'mega', status: 'active'),
  ],
  merchant: const CouponMerchantRef(id: 1, name: 'The Grand Downtown Corner Cafe and Bakery Emporium', logoUrl: null),
  issuedAt: DateTime(2026, 9, 11),
  annualCycleExpiresAt: DateTime(2027, 9, 11),
);

final _won = Coupon(
  id: 2,
  code: 'ZJOAWIGTNO5K',
  status: 'won',
  sourceType: 'purchase',
  eligibilities: const [
    CouponEligibility(cadence: 'weekly', status: 'closed'),
    CouponEligibility(cadence: 'monthly', status: 'won'),
    CouponEligibility(cadence: 'mega', status: 'active'),
  ],
  merchant: null,
  issuedAt: DateTime(2026, 9, 8),
  annualCycleExpiresAt: DateTime(2027, 9, 8),
);

final _expired = Coupon(
  id: 3,
  code: '0NG1FYPST3NW',
  status: 'expired',
  sourceType: 'referral_bonus',
  eligibilities: const [
    CouponEligibility(cadence: 'weekly', status: 'closed'),
    CouponEligibility(cadence: 'monthly', status: 'closed'),
    CouponEligibility(cadence: 'mega', status: 'closed'),
  ],
  merchant: null,
  issuedAt: DateTime(2025, 9, 1),
  annualCycleExpiresAt: DateTime(2026, 9, 1),
);

/// Filters like the API does and records which status each call asked for.
class _FakeCouponsRepository implements CouponsRepository {
  final statuses = <String?>[];

  @override
  Future<OffsetPage<Coupon>> list({int page = 1, int perPage = 20, String? status}) async {
    statuses.add(status);
    final items = [_active, _won, _expired].where((c) => status == null || c.status == status).toList();
    return OffsetPage(items: items, currentPage: 1, lastPage: 1, total: items.length);
  }

  @override
  Future<Coupon> show(int id) async => throw UnimplementedError();
}

Widget _wrap(_FakeCouponsRepository repository) {
  return ProviderScope(
    overrides: [
      couponsRepositoryProvider.overrideWithValue(repository),
      couponCountsProvider.overrideWith((ref) async => const CouponCounts(active: 22000, won: 6, expired: 0)),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const CouponsListScreen()),
  );
}

void main() {
  testWidgets('Coupons renders the header, banner, counted filters and every ticket kind at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      () => _wrap(_FakeCouponsRepository()),
      verify: (tester, size) async {
        expect(find.text('Lucky Draw coupons'), findsOneWidget);
        expect(find.text('Draws & prizes'), findsOneWidget);
        expect(find.text('22006'), findsOneWidget); // "All" is the sum of the three statuses
        expect(find.text('TICKET'), findsOneWidget);

        final page = find.byType(CustomScrollView);
        await tester.dragUntilVisible(find.text('WINNER'), page, const Offset(0, -200));
        expect(find.text('Winner'), findsOneWidget);
        await tester.dragUntilVisible(find.text('EXPIRED'), page, const Offset(0, -200));
      },
    );
  });

  testWidgets('a filter pill asks the API for that status, and the copy button confirms', (tester) async {
    final repository = _FakeCouponsRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    expect(repository.statuses.last, isNull);

    await tester.tap(find.text('Won'));
    await tester.pumpAndSettle();
    expect(repository.statuses.last, 'won');
    expect(find.text('TICKET'), findsNothing);
    expect(find.text('WINNER'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy coupon number'));
    await tester.pump();
    expect(find.text('Coupon number copied'), findsOneWidget);
  });
}
