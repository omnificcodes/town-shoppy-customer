import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/redemptions/application/pending_otp_codes_provider.dart';
import 'package:customer/features/redemptions/application/redemption_detail_provider.dart';
import 'package:customer/features/redemptions/application/redemptions_list_controller.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:customer/features/redemptions/data/models/redemption_initiation_result.dart';
import 'package:customer/features/redemptions/data/redemptions_repository.dart';
import 'package:customer/features/redemptions/presentation/redemption_verification_screen.dart';

import '../../helpers/responsive_test_helper.dart';

/// Same shape as `redemptions_list_controller_test.dart`'s identical fake
/// (this codebase duplicates small test fakes per file rather than sharing
/// a test helper) -- only `list()`/`listCallCount` are exercised here, to
/// confirm this screen invalidates the history list on settlement.
class _FakeRedemptionsRepository implements RedemptionsRepository {
  int listCallCount = 0;

  @override
  Future<OffsetPage<Redemption>> list({int page = 1, int perPage = 20}) async {
    listCallCount++;
    return const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  @override
  Future<Redemption> show(int id) async => throw UnimplementedError();

  @override
  Future<RedemptionInitiationResult> initiate({
    required int merchantId,
    required int branchId,
    required double billAmount,
    required String idempotencyKey,
  }) async =>
      throw UnimplementedError();
}

Redemption _redemption({required String status}) {
  return Redemption(
    id: 8,
    merchant: const RedemptionMerchantRef(id: 42, name: 'Suspended Redemption Test'),
    branch: const RedemptionMerchantRef(id: 42, name: 'Main Branch'),
    billAmount: 500,
    discountAmount: status == 'settled' ? 25 : null,
    remainingBillAmount: status == 'settled' ? 475 : null,
    coinsRequested: 250,
    coinsDebited: status == 'settled' ? 250 : null,
    status: status,
    verificationMethod: status == 'settled' ? 'otp' : null,
    verifiedAt: status == 'settled' ? DateTime(2026, 1, 1) : null,
    createdAt: DateTime(2026, 1, 1),
  );
}

(Widget, ProviderContainer) _wrapWithContainer(
  int redemptionId,
  Redemption redemption, {
  String? otpCode,
  RedemptionsRepository? repository,
}) {
  final container = ProviderContainer(
    overrides: [
      redemptionDetailProvider(redemptionId).overrideWith((ref) async => redemption),
      if (repository != null) redemptionsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  if (otpCode != null) {
    container.read(pendingOtpCodesProvider.notifier).stash(redemptionId, otpCode);
  }

  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light, home: RedemptionVerificationScreen(redemptionId: redemptionId)),
  );
  return (widget, container);
}

Widget _wrap(int redemptionId, Redemption redemption, {String? otpCode}) {
  return _wrapWithContainer(redemptionId, redemption, otpCode: otpCode).$1;
}

void main() {
  group('RedemptionVerificationScreen', () {
    testWidgets('an initiated redemption shows the OTP code and a waiting message', (tester) async {
      await tester.pumpWidget(_wrap(8, _redemption(status: 'initiated'), otpCode: '585937'));
      await tester.pump();
      await tester.pump();

      expect(find.text('585937'), findsOneWidget);
      expect(find.textContaining('Waiting for the merchant'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an initiated redemption without a code on this device explains how to proceed', (tester) async {
      await tester.pumpWidget(_wrap(8, _redemption(status: 'initiated')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Code not available'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an initiated redemption with an expiry shows a live countdown and flips to expired at zero', (
      tester,
    ) async {
      // The test binding fakes Timers but not DateTime.now(), so the screen
      // takes an injectable clock that this test advances by hand.
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final redemption = Redemption(
        id: 8,
        merchant: const RedemptionMerchantRef(id: 42, name: 'Countdown Cafe'),
        branch: null,
        billAmount: 500,
        discountAmount: null,
        remainingBillAmount: null,
        coinsRequested: 250,
        coinsDebited: null,
        status: 'initiated',
        verificationMethod: null,
        verifiedAt: null,
        createdAt: now,
        qrExpiresAt: now.add(const Duration(minutes: 2, seconds: 30)),
      );

      final container = ProviderContainer(
        overrides: [redemptionDetailProvider(8).overrideWith((ref) async => redemption)],
      );
      addTearDown(container.dispose);
      container.read(pendingOtpCodesProvider.notifier).stash(8, '585937');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: RedemptionVerificationScreen(redemptionId: 8, clock: () => now),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('585937'), findsOneWidget);
      expect(find.text('Expires in 02:30'), findsOneWidget);

      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Expires in 01:30'), findsOneWidget);

      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      // Let the AnimatedSwitcher's 200ms cross-fade finish so the old
      // waiting view (and its code) is actually gone, not mid-fade.
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('This redemption expired'), findsOneWidget);
      expect(find.text('585937'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a settled redemption shows the confirmation view with real discount/coins fields', (tester) async {
      await tester.pumpWidget(_wrap(8, _redemption(status: 'settled')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Redemption complete!'), findsOneWidget);
      expect(find.text('₹25.00'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an expired redemption shows the expired terminal view', (tester) async {
      await tester.pumpWidget(_wrap(8, _redemption(status: 'expired')));
      await tester.pump();
      await tester.pump();

      expect(find.text('This redemption expired'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a cancelled redemption shows the cancelled terminal view', (tester) async {
      await tester.pumpWidget(_wrap(8, _redemption(status: 'cancelled')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Redemption cancelled'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reaching settled invalidates the redemption history list so it stops showing a stale status', (tester) async {
      final fakeRepo = _FakeRedemptionsRepository();
      final (widget, container) = _wrapWithContainer(8, _redemption(status: 'settled'), repository: fakeRepo);
      addTearDown(container.dispose);

      // Warm the history provider first, same as if the customer had
      // already opened History before this redemption settled.
      await container.read(redemptionsListControllerProvider.future);
      expect(fakeRepo.listCallCount, 1);

      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump();
      // The post-frame callback above only *starts* the second list()
      // call -- await its future so the count reflects the completed
      // rebuild, not just the invalidation having fired.
      await container.read(redemptionsListControllerProvider.future);

      expect(fakeRepo.listCallCount, 2);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('remaining initiated does not invalidate the redemption history list', (tester) async {
      final fakeRepo = _FakeRedemptionsRepository();
      final (widget, container) = _wrapWithContainer(8, _redemption(status: 'initiated'), otpCode: '585937', repository: fakeRepo);
      addTearDown(container.dispose);

      await container.read(redemptionsListControllerProvider.future);
      expect(fakeRepo.listCallCount, 1);

      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump();

      expect(fakeRepo.listCallCount, 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the waiting view with a long merchant/branch name and OTP code renders without overflow at every viewport', (
      tester,
    ) async {
      final redemption = Redemption(
        id: 8,
        merchant: const RedemptionMerchantRef(id: 42, name: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium'),
        branch: const RedemptionMerchantRef(id: 42, name: 'Main Street Flagship Location and Customer Service Centre'),
        billAmount: 500,
        discountAmount: null,
        remainingBillAmount: null,
        coinsRequested: 250,
        coinsDebited: null,
        status: 'initiated',
        verificationMethod: null,
        verifiedAt: null,
        createdAt: DateTime(2026, 1, 1),
      );

      await forEachViewport(
        tester,
        () => _wrap(8, redemption, otpCode: '585937'),
        settle: false,
        verify: (tester, size) async {
          expect(find.textContaining('The Grand Downtown'), findsOneWidget);
          expect(find.text('585937'), findsOneWidget);
        },
      );
    });

    testWidgets('the confirmation view with a long merchant name and large amounts renders without overflow at every viewport', (
      tester,
    ) async {
      final redemption = Redemption(
        id: 8,
        merchant: const RedemptionMerchantRef(id: 42, name: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium'),
        branch: null,
        billAmount: 999999.99,
        discountAmount: 124999.99,
        remainingBillAmount: 874999.99,
        coinsRequested: 500000,
        coinsDebited: 500000,
        status: 'settled',
        verificationMethod: 'otp',
        verifiedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      await forEachViewport(
        tester,
        () => _wrap(8, redemption),
        settle: false,
        verify: (tester, size) async {
          expect(find.text('Redemption complete!'), findsOneWidget);
          expect(find.textContaining('The Grand Downtown'), findsOneWidget);
          expect(find.text('₹124999.99'), findsOneWidget);
          expect(find.text('500000'), findsOneWidget);
        },
      );
    });
  });
}
