import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/purchases/application/customer_purchase_request_controller.dart';
import 'package:customer/features/purchases/data/models/merchant_purchase_qr_resolution.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';
import 'package:customer/features/purchases/presentation/request_purchase_screen.dart';

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
  Future<Purchase> requestPurchase({
    required String token,
    required double billAmount,
    required String idempotencyKey,
  }) async => throw UnimplementedError();

  @override
  Future<Purchase> show(int id) async => throw UnimplementedError();

  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => throw UnimplementedError();
}

const _resolution = MerchantPurchaseQrResolution(
  merchantId: 42,
  merchantName: 'Corner Cafe',
  branchId: 7,
  branchName: 'Main Branch',
  branchAddressLine: 'MG Road',
);

(Widget, ProviderContainer) _wrapWithContainer({PurchasesRepository? repository}) {
  final container = ProviderContainer(
    overrides: [if (repository != null) purchasesRepositoryProvider.overrideWithValue(repository)],
  );
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light, home: const RequestPurchaseScreen()),
  );
  return (widget, container);
}

void main() {
  group('RequestPurchaseScreen', () {
    testWidgets('shows a loading skeleton while the scanned token is still resolving', (tester) async {
      final delay = Completer<void>();
      final fake = _FakePurchasesRepository(resolution: _resolution, resolveDelay: delay);
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      unawaited(container.read(customerPurchaseRequestControllerProvider.notifier).resolveScannedToken('tok_123'));
      await tester.pumpWidget(widget);
      await tester.pump();

      expect(find.text('Corner Cafe'), findsNothing);
      expect(find.text('Submit request'), findsNothing);

      delay.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an invalid/revoked QR shows the error state, not the form', (tester) async {
      final fake = _FakePurchasesRepository(resolveError: const NotFoundException());
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      await container.read(customerPurchaseRequestControllerProvider.notifier).resolveScannedToken('bad_token');
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Submit request'), findsNothing);
    });

    testWidgets('a resolved QR shows the merchant/branch and disables submit until a valid amount is entered', (
      tester,
    ) async {
      final fake = _FakePurchasesRepository(resolution: _resolution);
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      await container.read(customerPurchaseRequestControllerProvider.notifier).resolveScannedToken('tok_123');
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.textContaining('Main Branch'), findsOneWidget);

      final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Submit request');
      expect(tester.widget<ElevatedButton>(submitButtonFinder).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '500');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(submitButtonFinder).onPressed, isNotNull);
    });

    testWidgets('an amount outside the 0.01-1000000 bound keeps submit disabled and shows an inline error', (
      tester,
    ) async {
      final fake = _FakePurchasesRepository(resolution: _resolution);
      final (widget, container) = _wrapWithContainer(repository: fake);
      addTearDown(container.dispose);

      await container.read(customerPurchaseRequestControllerProvider.notifier).resolveScannedToken('tok_123');
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '1000001');
      await tester.pumpAndSettle();

      final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Submit request');
      expect(tester.widget<ElevatedButton>(submitButtonFinder).onPressed, isNull);
      expect(find.textContaining('Enter an amount between'), findsOneWidget);
    });
  });
}
