import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/auth_repository.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/otp_request_result.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/auth/presentation/login_screen.dart';
import 'package:customer/features/merchants/application/merchant_branches_provider.dart';
import 'package:customer/features/merchants/application/merchant_detail_provider.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/presentation/merchant_detail_screen.dart';
import 'package:customer/features/notifications/application/notifications_controller.dart';
import 'package:customer/features/notifications/data/models/app_notification.dart';
import 'package:customer/features/notifications/presentation/notifications_screen.dart';
import 'package:customer/features/profile/presentation/profile_screen.dart';
import 'package:customer/features/redemptions/application/redemption_detail_provider.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:customer/features/redemptions/presentation/redemption_verification_screen.dart';

/// Section 20-24 of the Phase 10 brief: a practical text-scaling stress
/// test on a representative set of screens (login, a data-heavy detail
/// screen, the redemption flow, notifications, profile) at 1.3x (a common
/// "Larger Text" accessibility setting) and 2.0x (the top of what iOS/
/// Android expose without switching to the separate "bold/huge" AT modes).
/// Any genuine, unfixable limitation found here is reported honestly rather
/// than hidden by truncating/clipping text to make the assertion pass.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Account> me() async => throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<AuthResult> login({required String mobileNumber, required String password}) async => throw UnimplementedError();
  @override
  Future<AuthResult> register({
    required String mobileNumber,
    required String name,
    required String password,
    String? referralCode,
  }) async => throw UnimplementedError();
  @override
  Future<OtpRequestResult> forgotPassword({required String mobileNumber, String? channel}) async =>
      throw UnimplementedError();
  @override
  Future<void> resetPassword({
    required String mobileNumber,
    required int otpRequestId,
    required String code,
    required String password,
  }) async => throw UnimplementedError();
}

class _FakeEmptySecureStorage implements SecureStorageService {
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> delete(String key) async {}
}

const _account = Account(
  id: 1,
  mobileNumber: '9990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['customer'],
  customerProfile: CustomerProfile(
    id: 1,
    name: 'Priya Sharma',
    dateOfBirth: null,
    anniversaryDate: null,
    socialLinks: null,
    referralCode: 'ABC123',
    status: 'active',
  ),
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

const _merchant = Merchant(
  id: 1,
  name: 'The Grand Downtown Corner Cafe',
  description: 'Locally roasted coffee and fresh-baked pastries every day of the week.',
  logoUrl: null,
  websiteUrl: null,
  contactMobileNumber: null,
  socialLinks: null,
  discountRate: 12.5,
  acceptsTownCoin: true,
  category: null,
  association: AssociationRef(id: 1, name: 'Downtown Association', slug: 'downtown', town: null),
  branch: null,
);

const _branches = [
  MerchantBranchRef(
    id: 1,
    name: 'Main Street',
    isPrimary: true,
    addressLine: 'MG Road',
    locality: null,
    city: 'Springfield',
    state: null,
    postalCode: null,
    country: null,
    latitude: 1.0,
    longitude: 2.0,
    distanceKm: null,
  ),
];

class _NotificationsStub extends NotificationsController {
  @override
  Future<NotificationsListState> build() async => NotificationsListState(
    items: [
      AppNotification(
        id: 1,
        channel: 'in_app',
        type: 'redemption.completed',
        title: 'Your redemption was completed',
        body: 'Your Town Coin redemption for ₹500.00 has been verified and settled.',
        data: const {},
        status: 'delivered',
        sentAt: DateTime(2026, 1, 1),
        readAt: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ],
    nextCursor: null,
  );
}

final _redemption = Redemption(
  id: 8,
  merchant: const RedemptionMerchantRef(id: 42, name: 'The Grand Downtown Corner Cafe'),
  branch: const RedemptionMerchantRef(id: 42, name: 'Main Street'),
  billAmount: 500,
  discountAmount: 25,
  remainingBillAmount: 475,
  coinsRequested: 250,
  coinsDebited: 250,
  status: 'settled',
  verificationMethod: 'otp',
  verifiedAt: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
);

Widget _scaled(double factor, Widget child) {
  return Builder(
    builder: (context) {
      final mq = MediaQuery.of(context);
      return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(factor)), child: child);
    },
  );
}

Future<void> _pumpAtScale(WidgetTester tester, double factor, Widget Function() app) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(app());
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final scale in [1.3, 2.0]) {
    testWidgets('LoginScreen survives ${scale}x text scaling without overflow', (tester) async {
      await _pumpAtScale(
        tester,
        scale,
        () => ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            secureStorageServiceProvider.overrideWithValue(_FakeEmptySecureStorage()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: _scaled(scale, const LoginScreen()),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'LoginScreen overflowed at ${scale}x text scale');
    });

    testWidgets('MerchantDetailScreen survives ${scale}x text scaling without overflow', (tester) async {
      await _pumpAtScale(
        tester,
        scale,
        () => ProviderScope(
          overrides: [
            merchantDetailProvider(1).overrideWith((ref) async => _merchant),
            merchantBranchesProvider(1).overrideWith((ref) async => _branches),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: _scaled(scale, const MerchantDetailScreen(merchantId: 1)),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'MerchantDetailScreen overflowed at ${scale}x text scale');
    });

    testWidgets('RedemptionVerificationScreen (confirmation view) survives ${scale}x text scaling without overflow', (
      tester,
    ) async {
      await _pumpAtScale(
        tester,
        scale,
        () => ProviderScope(
          overrides: [redemptionDetailProvider(8).overrideWith((ref) async => _redemption)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: _scaled(scale, const RedemptionVerificationScreen(redemptionId: 8)),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'RedemptionVerificationScreen overflowed at ${scale}x text scale');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('NotificationsScreen survives ${scale}x text scaling without overflow', (tester) async {
      await _pumpAtScale(
        tester,
        scale,
        () => ProviderScope(
          overrides: [notificationsControllerProvider.overrideWith(_NotificationsStub.new)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: _scaled(scale, const NotificationsScreen()),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'NotificationsScreen overflowed at ${scale}x text scale');
    });

    testWidgets('ProfileScreen survives ${scale}x text scaling without overflow', (tester) async {
      await _pumpAtScale(
        tester,
        scale,
        () => ProviderScope(
          overrides: [authControllerProvider.overrideWith(_AuthenticatedController.new)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: _scaled(scale, const ProfileScreen()),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'ProfileScreen overflowed at ${scale}x text scale');
    });
  }
}
