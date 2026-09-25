import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:customer/features/redemptions/data/redemptions_repository.dart';
import 'package:customer/features/redemptions/presentation/redemptions_list_screen.dart';

import '../../helpers/responsive_test_helper.dart';

class _FakeRedemptionsRepository implements RedemptionsRepository {
  @override
  Future<OffsetPage<Redemption>> list({int page = 1, int perPage = 20}) async => OffsetPage(
    items: [
      Redemption(
        id: 1,
        merchant: const RedemptionMerchantRef(id: 1, name: 'The Grand Downtown Corner Cafe and Bakery Emporium'),
        branch: const RedemptionMerchantRef(id: 2, name: 'Main Street Flagship Location'),
        billAmount: 999999.99,
        discountAmount: null,
        remainingBillAmount: null,
        coinsRequested: 500000,
        coinsDebited: null,
        status: 'initiated',
        verificationMethod: null,
        verifiedAt: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ],
    currentPage: 1,
    lastPage: 1,
    total: 1,
  );

  @override
  Future<Redemption> show(int id) async => throw UnimplementedError();
}

Widget _wrap() {
  return ProviderScope(
    overrides: [redemptionsRepositoryProvider.overrideWithValue(_FakeRedemptionsRepository())],
    child: MaterialApp(theme: AppTheme.light, home: const RedemptionsListScreen()),
  );
}

void main() {
  testWidgets('RedemptionsListScreen renders a long merchant name and large coin amount without overflow', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Redemptions'), findsOneWidget);
        expect(find.textContaining('The Grand Downtown'), findsOneWidget);
        expect(find.textContaining('500000 coins'), findsOneWidget);
      },
    );
  });
}
