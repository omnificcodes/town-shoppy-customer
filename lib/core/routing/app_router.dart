import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/auth/presentation/mobile_number_screen.dart';
import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/merchants/presentation/merchant_detail_screen.dart';
import '../../features/merchants/presentation/merchants_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/purchases/presentation/purchase_detail_screen.dart';
import '../../features/purchases/presentation/purchases_list_screen.dart';
import '../../features/redemptions/presentation/redemption_detail_screen.dart';
import '../../features/redemptions/presentation/redemption_initiation_screen.dart';
import '../../features/redemptions/presentation/redemption_verification_screen.dart';
import '../../features/redemptions/presentation/redemptions_list_screen.dart';
import '../../features/referrals/presentation/referral_screen.dart';
import '../widgets/app_shell.dart';

const _splashPath = '/splash';
const _loginPath = '/login';
const _otpPath = '/otp';
const _completeProfilePath = '/complete-profile';
const _homePath = '/home';
const _notificationsPath = '/notifications';
const _profilePath = '/profile';
const _purchasesPath = '/purchases';
const _redemptionsPath = '/redemptions';
const _referralsPath = '/referrals';
const _merchantsPath = '/merchants';

/// Auth-aware [GoRouter]. Redirect logic — not widget-level checks — is the
/// single source of truth for "who can see what" (section 13: "do not rely
/// only on widget-level redirects").
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: _splashPath,
    refreshListenable: notifier,
    redirect: (context, state) => _redirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: _splashPath, builder: (context, state) => const _SplashScreen()),
      GoRoute(path: _loginPath, builder: (context, state) => const MobileNumberScreen()),
      GoRoute(path: _otpPath, builder: (context, state) => const OtpVerifyScreen()),
      GoRoute(path: _completeProfilePath, builder: (context, state) => const CompleteProfileScreen()),
      GoRoute(path: _purchasesPath, builder: (context, state) => const PurchasesListScreen()),
      GoRoute(
        path: '$_purchasesPath/:id',
        builder: (context, state) => PurchaseDetailScreen(purchaseId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: _redemptionsPath, builder: (context, state) => const RedemptionsListScreen()),
      GoRoute(
        path: '$_redemptionsPath/:id',
        builder: (context, state) => RedemptionDetailScreen(redemptionId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '$_redemptionsPath/:id/verify',
        builder: (context, state) => RedemptionVerificationScreen(redemptionId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: _referralsPath, builder: (context, state) => const ReferralScreen()),
      GoRoute(path: _merchantsPath, builder: (context, state) => const MerchantsListScreen()),
      GoRoute(
        path: '$_merchantsPath/:id',
        builder: (context, state) => MerchantDetailScreen(merchantId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '$_merchantsPath/:id/redeem',
        builder: (context, state) => RedemptionInitiationScreen(merchantId: int.parse(state.pathParameters['id']!)),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: _homePath, builder: (context, state) => const HomeScreen()),
          GoRoute(path: _notificationsPath, builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: _profilePath, builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

String? _redirect(AuthState authState, String location) {
  final onSplash = location == _splashPath;
  final onLogin = location == _loginPath;
  final onOtp = location == _otpPath;
  final onCompleteProfile = location == _completeProfilePath;
  final onProtected = !onSplash && !onLogin && !onOtp && !onCompleteProfile;

  return switch (authState) {
    AuthInitial() => onSplash ? null : _splashPath,
    AuthUnauthenticated() || AuthSessionExpired() => onLogin ? null : _loginPath,
    AuthOtpSent() => onOtp ? null : _otpPath,
    AuthProfileRequired() => onCompleteProfile ? null : _completeProfilePath,
    AuthAuthenticated() => onProtected ? null : _homePath,
  };
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Bridges Riverpod's [authControllerProvider] to go_router's
/// [Listenable]-based `refreshListenable`, so a state change (login,
/// logout, session expiry) immediately re-evaluates [_redirect] instead of
/// only on the next navigation event.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(authControllerProvider, (previous, next) => notifyListeners());
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
