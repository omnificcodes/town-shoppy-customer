import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/business_branches_controller.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/direct_pos_repository.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/data/models/direct_pos.dart';
import 'package:customer/features/business/presentation/direct_pos/direct_pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_test_helper.dart';

const _account = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['merchant_owner'],
  customerProfile: null,
  merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

/// Lookup and preview are scripted; submit is never reached here.
class _FakeDirectPosRepository implements DirectPosRepository {
  @override
  Future<CustomerLookupResult> lookupCustomer({required int merchantId, required String mobileNumber}) async {
    return CustomerLookupResult.fromJson({
      'registered': true,
      'id': 9,
      'name': 'Rahul Sharma Kuttikkattil Parambil',
      'mobile_number': '+919876543210',
      'purchase_count': 1234,
      'total_spent': 9876543.21,
      'last_purchase_at': '2026-09-13 10:11:12',
    });
  }

  @override
  Future<DirectPosPreview> preview({
    required int merchantId,
    required DirectPosIdentity identity,
    required double billAmount,
    int? branchId,
  }) async {
    return DirectPosPreview.fromJson({
      'bill_amount': 850,
      'customer_name': 'Rahul Sharma',
      'available_balance': 240,
      'max_discount_amount': '60',
      'max_redeemable_coins': 120,
      'payable_amount': '790',
    });
  }

  @override
  Future<DirectPosResult> submit({
    required int merchantId,
    required DirectPosIdentity identity,
    required double billAmount,
    required bool redeem,
    required String idempotencyKey,
    int? branchId,
    String? billReference,
    int? scratchCardId,
    int? stampCardId,
  }) => throw UnimplementedError();
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      directPosRepositoryProvider.overrideWithValue(_FakeDirectPosRepository()),
      activeBranchesProvider.overrideWithValue(const []),
      myMerchantProvider.overrideWith(
        (ref) async => BusinessMerchant.fromJson({'id': 5, 'name': 'Kairaly Bakers', 'status': 'active'}),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const DirectPosScreen()),
  );
}

void main() {
  testWidgets('the counter finds the customer and shows the discount by itself, without overflow at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Direct POS'), findsOneWidget);
        expect(find.text('KAIRALY BAKERS'), findsOneWidget);
        expect(find.text('Mobile number'), findsOneWidget);
        expect(find.text('Scan customer QR'), findsOneWidget);

        // A complete number is enough -- no Search button to press. Two
        // pumps: the first builds the frame that schedules the debounce,
        // the second lets it elapse (pumpAndSettle waits on frames, and a
        // pending Timer schedules none).
        await tester.enterText(find.byType(TextField).first, '9876543210');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(find.text('Search'), findsNothing);
        expect(find.text('Rahul Sharma Kuttikkattil Parambil'), findsOneWidget);
        expect(find.text('1234'), findsOneWidget);

        // An amount is enough for the discount -- no Preview button either.
        final amount = find.byType(TextField).at(1);
        await tester.ensureVisible(amount);
        await tester.enterText(amount, '850');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('Preview discount'), findsNothing);
        expect(find.text('Redeeming 120 coins'), findsOneWidget);
        expect(find.text('Available balance: 240 coins'), findsOneWidget);

        // The total and the CTA sit below the fold of a lazy ListView, so
        // they only exist once scrolled to.
        await tester.scrollUntilVisible(find.text('Customer pays'), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text('Customer pays'), findsOneWidget);
        expect(find.text('Record purchase'), findsOneWidget);
      },
    );
  });

  testWidgets('switching to Scan customer QR offers the scanner', (tester) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        await tester.tap(find.text('Scan customer QR'));
        await tester.pumpAndSettle();
        expect(find.text('Open scanner'), findsOneWidget);
        expect(find.text('Search'), findsNothing);
      },
    );
  });
}
