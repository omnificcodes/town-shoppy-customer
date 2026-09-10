import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/profile/presentation/profile_screen.dart';

import '../../helpers/responsive_test_helper.dart';

const _account = Account(
  id: 1,
  mobileNumber: '9990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['customer'],
  customerProfile: CustomerProfile(
    id: 1,
    name: 'Venkataramanujachandrasekaran Padmanabhaswamy Iyengar',
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

Widget _wrap() {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(_AuthenticatedController.new)],
    child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
  );
}

void main() {
  testWidgets('ProfileScreen renders a long display name without overflow at every mandated viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.textContaining('Venkataramanujachandrasekaran'), findsOneWidget);
        expect(find.text('Purchases'), findsOneWidget);
        expect(find.text('Redemptions'), findsOneWidget);
        expect(find.text('Referrals'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
      },
    );
  });
}
