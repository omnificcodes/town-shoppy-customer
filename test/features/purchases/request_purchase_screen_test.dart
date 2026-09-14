import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/purchases/data/models/merchant_purchase_qr_resolution.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';
import 'package:customer/features/purchases/presentation/request_purchase_screen.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

class _FakePurchasesRepository implements PurchasesRepository {
  _FakePurchasesRepository({this.resolution, this.resolveError, this.resolveDelay});

  MerchantPurchaseQrResolution? resolution;
  AppException? resolveError;
  Completer<void>? resolveDelay;

  @override
  Future<MerchantPurchaseQrResolution> resolveMerchantQr(String token) async {
    if (resolveDelay != null) await resolveDelay!.future;
    if (resolveError != null) throw resolveError!;
    return resolution!;
  }

  @override
  Future<CounterPurchaseResult> requestPurchase({
    required String token,
    required double billAmount,
    required String idempotencyKey,
    bool redeem = false,
  }) async => throw UnimplementedError();

  @override
  Future<Purchase> show(int id) async => throw UnimplementedError();

  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => throw UnimplementedError();
}

/// The screen estimates the saving from the wallet, so every test gets a
/// real balance instead of reaching for the network: 800 coins, worth ₹80.
class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async => const SilverWalletBalance(
        balance: 800,
        universalBalance: 800,
        shopExclusiveBalance: 0,
        shopExclusiveBreakdown: [],
        balanceInrEquivalent: 80,
        updatedAt: null,
      );

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => throw UnimplementedError();
}

/// A merchant that takes Town Coin at 7% of the bill.
const _resolution = MerchantPurchaseQrResolution(
  merchantId: 42,
  merchantName: 'Corner Cafe',
  branchId: 7,
  branchName: 'Main Branch',
  branchAddressLine: 'MG Road',
  acceptsTownCoin: true,
  discountRate: 7,
);

(Widget, ProviderContainer) _wrapWithContainer({PurchasesRepository? repository, String scannedToken = 'tok_123'}) {
  final container = ProviderContainer(
    overrides: [
      if (repository != null) purchasesRepositoryProvider.overrideWithValue(repository),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
    ],
  );
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light, home: RequestPurchaseScreen(scannedToken: scannedToken)),
  );
  return (widget, container);
}

void main() {
  group('RequestPurchaseScreen', () {
    // Resolution is triggered by the screen itself (in initState, before its
    // first build ever watches the controller) rather than by the caller
    // reading the controller ahead of pumpWidget -- that older shape is
    // exactly the read-then-abandon race that used to leave a real scan on
    // a blank screen (the autoDispose controller had no listener between
    // the scan screen's `ref.read` and this screen's first `ref.watch`, so
    // it was disposed -- taking the in-flight resolution with it -- before
    // this screen ever saw the result).
    testWidgets('shows a loading skeleton while the scanned token is still resolving', (tester) async {
      final delay = Completer<void>();
      final fake = _FakePurchasesRepository(resolution: _resolution, resolveDelay: delay);
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      await tester.pumpWidget(widget);
      await tester.pump();

      expect(find.text('Corner Cafe'), findsNothing);
      expect(find.text('Continue'), findsNothing);

      delay.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an invalid/revoked QR shows the error state, not the form', (tester) async {
      final fake = _FakePurchasesRepository(resolveError: const NotFoundException());
      final (widget, container) = _wrapWithContainer(repository: fake, scannedToken: 'bad_token');
      addTearDown(container.dispose);

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('a resolved QR shows the merchant/branch and disables Continue until a valid amount is entered', (
      tester,
    ) async {
      final fake = _FakePurchasesRepository(resolution: _resolution);
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.textContaining('Main Branch'), findsOneWidget);

      final continueFinder = find.widgetWithText(ElevatedButton, 'Continue');
      expect(tester.widget<ElevatedButton>(continueFinder).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '500');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(continueFinder).onPressed, isNotNull);
    });

    testWidgets('an amount outside the 0.01-1000000 bound keeps Continue disabled and shows an inline error', (
      tester,
    ) async {
      final fake = _FakePurchasesRepository(resolution: _resolution);
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '1000001');
      await tester.pumpAndSettle();

      final continueFinder = find.widgetWithText(ElevatedButton, 'Continue');
      expect(tester.widget<ElevatedButton>(continueFinder).onPressed, isNull);
      expect(find.textContaining('Enter an amount between'), findsOneWidget);
    });

    testWidgets('the saving appears as the bill is typed, and review shows the bill, discount and amount to pay', (
      tester,
    ) async {
      final fake = _FakePurchasesRepository(resolution: _resolution);
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // 7% of ₹5000 is ₹350, but 800 coins are only worth ₹80, so the
      // wallet is the cap -- the same rule the server applies.
      await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '5000');
      await tester.pumpAndSettle();
      expect(find.text('You save ₹80.00'), findsOneWidget);

      final continueFinder = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(continueFinder);
      await tester.tap(continueFinder);
      await tester.pumpAndSettle();

      expect(find.text('− ₹80.00'), findsOneWidget);

      // The Pay button sits below the breakdown, past the fold on a test-sized screen.
      final payFinder = find.widgetWithText(ElevatedButton, 'Pay ₹4920.00');
      await tester.dragUntilVisible(payFinder, find.byType(ListView).first, const Offset(0, -200));
      expect(tester.widget<ElevatedButton>(payFinder).onPressed, isNotNull);
    });
  });
}
