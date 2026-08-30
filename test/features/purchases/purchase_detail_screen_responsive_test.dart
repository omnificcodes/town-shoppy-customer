import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/purchases/application/purchase_detail_provider.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/presentation/purchase_detail_screen.dart';

import '../../helpers/responsive_test_helper.dart';

final _purchase = Purchase(
  id: 1,
  merchantId: 1,
  merchant: const PurchaseMerchantRef(id: 1, name: 'The Grand Downtown Corner Cafe and Bakery Emporium'),
  branch: const PurchaseMerchantRef(id: 2, name: 'Main Street Flagship Location and Customer Service Centre'),
  billAmount: 999999.99,
  currency: 'INR',
  billReference: 'INV-2026-000001-VERY-LONG-REFERENCE-NUMBER-FROM-THE-MERCHANT-POS',
  coinsAwarded: 500000,
  couponsIssued: 12,
  status: 'recorded',
  createdAt: DateTime(2026, 1, 1, 14, 30),
);

Widget _wrap() {
  return ProviderScope(
    overrides: [purchaseDetailProvider(1).overrideWith((ref) async => _purchase)],
    child: MaterialApp(theme: AppTheme.light, home: const PurchaseDetailScreen(purchaseId: 1)),
  );
}

void main() {
  testWidgets('PurchaseDetailScreen renders long merchant/branch/reference and a large amount without overflow', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.textContaining('The Grand Downtown'), findsOneWidget);
        expect(find.text('₹999999.99'), findsOneWidget);
        expect(find.text('Coins awarded'), findsOneWidget);
        expect(find.text('Coupons issued'), findsOneWidget);
        expect(find.text('Bill reference'), findsOneWidget);
      },
    );
  });
}
