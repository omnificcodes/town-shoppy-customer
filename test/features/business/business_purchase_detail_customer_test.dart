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

  group('a Town Coin payment request', () {
    Purchase pending({required String coinStatus}) => Purchase.fromJson({
      'id': 25,
      'transaction_id': 'TC000025',
      'merchant_id': 5,
      'bill_amount': 500,
      'currency': 'INR',
      'source': 'customer_merchant_qr',
      'coins_awarded': 0,
      'status': coinStatus == 'settled' ? 'recorded' : 'pending',
      'coin_payment': {
        'redemption_id': 11,
        'status': coinStatus,
        'settled': coinStatus == 'settled',
        'coins': 230,
        'discount_amount': '23.00',
        'amount_payable': '477.00',
      },
      'customer': {'id': 9, 'name': 'Asha', 'mobile_number': '+919876543210'},
      'created_at': '2026-09-25T15:15:00+05:30',
    });

    // Tall enough to build every section, so "not found" means not there.
    void tallWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(420, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('shows the transaction ID, the coins approval deducts, and what to collect', (tester) async {
      tallWindow(tester);
      await tester.pumpWidget(_wrap(pending(coinStatus: 'initiated')));
      await tester.pumpAndSettle();

      expect(find.text('Town Coin payment'), findsOneWidget);
      expect(find.text('TC000025'), findsOneWidget);
      expect(find.text('Deducted on approval'), findsOneWidget);
      expect(find.text('Coins to deduct'), findsOneWidget);
      expect(find.text('230 Town Coins'), findsOneWidget);
      expect(find.text('Collect at the counter'), findsOneWidget);
      expect(find.text('₹477.00'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('Approve says what it deducts and what to collect, before the tap', (tester) async {
      tallWindow(tester);
      await tester.pumpWidget(_wrap(pending(coinStatus: 'initiated')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Approve this payment?'), findsOneWidget);
      expect(
        find.text('This deducts 230 Town Coins from the customer and records the sale. Collect ₹477.00 at the counter.'),
        findsOneWidget,
      );
    });

    testWidgets('once settled, reads as deducted', (tester) async {
      tallWindow(tester);
      await tester.pumpWidget(_wrap(pending(coinStatus: 'settled')));
      await tester.pumpAndSettle();

      expect(find.text('Deducted'), findsOneWidget);
      expect(find.text('Coins deducted'), findsOneWidget);
      expect(find.text('Collected at the counter'), findsOneWidget);
    });

    testWidgets('a coin payment that never went through says so, and changes nothing collected', (tester) async {
      tallWindow(tester);
      await tester.pumpWidget(_wrap(pending(coinStatus: 'cancelled')));
      await tester.pumpAndSettle();

      expect(find.text('Not deducted'), findsOneWidget);
      expect(find.text('Coins requested'), findsOneWidget);
      expect(find.textContaining('Collect'), findsNothing);
    });
  });
}
