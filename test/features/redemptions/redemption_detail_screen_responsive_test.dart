import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/redemptions/application/redemption_detail_provider.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:customer/features/redemptions/presentation/redemption_detail_screen.dart';

import '../../helpers/responsive_test_helper.dart';

final _redemption = Redemption(
  id: 1,
  merchant: const RedemptionMerchantRef(id: 1, name: 'The Grand Downtown Corner Cafe and Bakery Emporium'),
  branch: const RedemptionMerchantRef(id: 2, name: 'Main Street Flagship Location and Customer Service Centre'),
  billAmount: 999999.99,
  discountAmount: 124999.99,
  remainingBillAmount: 874999.99,
  coinsRequested: 500000,
  coinsDebited: 500000,
  status: 'settled',
  verificationMethod: 'otp',
  verifiedAt: DateTime(2026, 1, 1, 14, 30),
  createdAt: DateTime(2026, 1, 1, 14, 20),
);

Widget _wrap() {
  return ProviderScope(
    overrides: [redemptionDetailProvider(1).overrideWith((ref) async => _redemption)],
    child: MaterialApp(theme: AppTheme.light, home: const RedemptionDetailScreen(redemptionId: 1)),
  );
}

void main() {
  testWidgets('RedemptionDetailScreen renders long merchant/branch names and large amounts without overflow', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.textContaining('The Grand Downtown'), findsOneWidget);
        expect(find.text('500000 coins'), findsOneWidget);
        expect(find.text('₹999999.99'), findsOneWidget);
        expect(find.text('Verified via'), findsOneWidget);
      },
    );
  });
}
