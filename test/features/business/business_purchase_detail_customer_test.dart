import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_purchases_controller.dart';
import 'package:customer/features/business/presentation/purchases/business_purchase_detail_screen.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_test_helper.dart';

Purchase _purchase({Map<String, dynamic>? customer}) => Purchase.fromJson({
  'id': 25,
  'merchant_id': 5,
  'branch': {'id': 7, 'name': 'Main Branch'},
  'bill_amount': 200,
  'currency': 'INR',
  'source': 'customer_merchant_qr',
  'coins_awarded': 20,
  'coupons_issued': 0,
  'status': 'recorded',
  'customer': ?customer,
  'created_at': '2026-09-16T15:15:00+05:30',
});

Widget _wrap(Purchase purchase) => ProviderScope(
  overrides: [businessPurchaseProvider(25).overrideWith((ref) async => purchase)],
  child: MaterialApp(theme: AppTheme.light, home: const BusinessPurchaseDetailScreen(purchaseId: 25)),
);

void main() {
  testWidgets('shows who made the purchase: name and a formatted mobile number, at every viewport', (tester) async {
    await forEachViewport(
      tester,
      () => _wrap(
        _purchase(
          customer: {'id': 9, 'name': 'Pranav Krishnakumar Menon Thekkedath', 'mobile_number': '+919876543210'},
        ),
      ),
      verify: (tester, size) async {
        expect(find.text('Customer'), findsOneWidget);
        expect(find.text('Pranav Krishnakumar Menon Thekkedath'), findsOneWidget);
        expect(find.text('+91 98765 43210'), findsOneWidget);
        // Tappable to call the customer.
        expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      },
    );
  });

  testWidgets('a customer with no name on file reads "Not provided"', (tester) async {
    await tester.pumpWidget(_wrap(_purchase(customer: {'id': 9, 'name': null, 'mobile_number': '+919876543210'})));
    await tester.pumpAndSettle();

    expect(find.text('Not provided'), findsOneWidget);
  });

  testWidgets('without customer details the section is not shown', (tester) async {
    await tester.pumpWidget(_wrap(_purchase()));
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsNothing);
    expect(find.text('Purchase details'), findsOneWidget);
  });
}
