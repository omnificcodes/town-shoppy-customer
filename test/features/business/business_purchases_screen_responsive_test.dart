import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/business_activity_repository.dart';
import 'package:customer/features/business/data/models/management_totals.dart';
import 'package:customer/features/business/presentation/purchases/business_purchases_screen.dart';
import 'package:customer/features/notifications/application/unread_count_provider.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_test_helper.dart';

final _pending = Purchase.fromJson({
  'id': 4821,
  'merchant_id': 5,
  'bill_amount': 1234567.89,
  'currency': 'INR',
  'bill_reference': 'INV-2026-09-ERNAKULAM-MAIN-COUNTER-000123',
  'status': 'pending',
  'coins_awarded': 0,
  'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
});

/// Only the list read is scripted; it records which status each call asked
/// for, so the pills can be proven to filter on the server.
class _FakeActivityRepository extends BusinessActivityRepository {
  _FakeActivityRepository({this.empty = false}) : super(Dio());

  final bool empty;
  final statuses = <String?>[];

  @override
  Future<ManagementPage<Purchase, PurchaseTotals>> purchasesPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? merchantId,
    int? branchId,
    String? from,
    String? search,
  }) async {
    statuses.add(status);
    final items = empty ? const <Purchase>[] : [_pending];
    return ManagementPage(
      items: items,
      currentPage: 1,
      lastPage: 1,
      total: items.length,
      totals: PurchaseTotals(
        purchases: empty ? 0 : 98765,
        billAmount: empty ? 0 : 123456789.5,
        coinsAwarded: empty ? 0 : 4567890,
        pending: empty ? 0 : 12,
      ),
    );
  }
}

Widget _wrap(_FakeActivityRepository repository) {
  return ProviderScope(
    overrides: [
      businessActivityRepositoryProvider.overrideWithValue(repository),
      myMerchantIdProvider.overrideWithValue(5),
      unreadNotificationCountProvider.overrideWith((ref) async => 4),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const BusinessPurchasesScreen()),
  );
}

void main() {
  testWidgets('Purchases renders the header stats, filters and a pending row without overflow at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      () => _wrap(_FakeActivityRepository()),
      verify: (tester, size) async {
        expect(find.text('Purchases'), findsOneWidget);
        expect(find.text('BUSINESS'), findsOneWidget);
        expect(find.text('₹123456789.50'), findsOneWidget);
        expect(find.text('98765'), findsOneWidget);
        expect(find.text('ALL TIME'), findsOneWidget);
        expect(find.text('TOWN COINS'), findsOneWidget);
        expect(find.text('Awaiting approval'), findsWidgets);
        expect(find.text('12'), findsOneWidget);

        final page = find.byType(CustomScrollView);
        await tester.dragUntilVisible(find.text('Approve'), page, const Offset(0, -250));
        expect(find.text('Approve'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('₹1234567.89'), findsOneWidget);
      },
    );
  });

  testWidgets('an empty approval queue says so and offers Direct POS', (tester) async {
    await forEachViewport(
      tester,
      () => _wrap(_FakeActivityRepository(empty: true)),
      verify: (tester, size) async {
        final page = find.byType(CustomScrollView);
        await tester.dragUntilVisible(find.text('Record a purchase (Direct POS)'), page, const Offset(0, -250));
        expect(find.text('Nothing awaiting approval'), findsOneWidget);
        expect(find.text('Record a purchase (Direct POS)'), findsOneWidget);
      },
    );
  });

  testWidgets('picking All purchases asks the API for every status', (tester) async {
    final repository = _FakeActivityRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    expect(repository.statuses.last, 'pending');

    await tester.tap(find.text('All purchases'));
    await tester.pumpAndSettle();
    expect(repository.statuses.last, isNull);

    // Leave the polling approval queue so no timer outlives the test.
    await tester.pumpWidget(const SizedBox());
  });
}
