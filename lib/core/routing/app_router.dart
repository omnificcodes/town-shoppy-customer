import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/coupons/presentation/coupon_detail_screen.dart';
import '../../features/coupons/presentation/coupons_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lucky_draw/presentation/draw_detail_screen.dart';
import '../../features/lucky_draw/presentation/draws_list_screen.dart';
import '../../features/lucky_draw/presentation/my_vouchers_screen.dart';
import '../../features/lucky_draw/presentation/voucher_detail_screen.dart';
import '../../features/merchants/presentation/merchant_detail_screen.dart';
import '../../features/merchants/presentation/merchants_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/purchases/presentation/my_qr_screen.dart';
import '../../features/purchases/presentation/purchase_detail_screen.dart';
import '../../features/purchases/presentation/purchases_list_screen.dart';
import '../../features/purchases/presentation/request_purchase_screen.dart';
import '../../features/purchases/presentation/scan_merchant_qr_screen.dart';
import '../../features/redemptions/presentation/redeem_offers_screen.dart';
import '../../features/redemptions/presentation/redemption_detail_screen.dart';
import '../../features/redemptions/presentation/redemption_initiation_screen.dart';
import '../../features/redemptions/presentation/redemption_verification_screen.dart';
import '../../features/redemptions/presentation/redemptions_list_screen.dart';
import '../../features/referrals/presentation/referral_screen.dart';
import '../widgets/app_shell.dart';

const _splashPath = '/splash';
const _loginPath = '/login';
const _registerPath = '/register';
const _homePath = '/home';
const _walletPath = '/wallet';
const _notificationsPath = '/notifications';
const _profilePath = '/profile';
const _purchasesPath = '/purchases';
const _couponsPath = '/coupons';
const _luckyDrawPath = '/lucky-draw';
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
      GoRoute(path: _loginPath, builder: (context, state) => const LoginScreen()),
      GoRoute(path: _registerPath, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: _purchasesPath, builder: (context, state) => const PurchasesListScreen()),
      // 3-way purchase architecture, Method 1/3 — registered before
      // /purchases/:id below so "scan"/"request"/"my-qr" are never parsed
      // as a purchase id (same precedent as /referrals/me elsewhere).
      GoRoute(path: '$_purchasesPath/scan', builder: (context, state) => const ScanMerchantQrScreen()),
      GoRoute(
        path: '$_purchasesPath/request',
        builder: (context, state) => RequestPurchaseScreen(scannedToken: state.extra as String),
      ),
      GoRoute(path: '$_purchasesPath/my-qr', builder: (context, state) => const MyQrScreen()),
      GoRoute(
        path: '$_purchasesPath/:id',
        builder: (context, state) => PurchaseDetailScreen(purchaseId: int.parse(state.pathParameters['id']!)),
      ),
      // The /coupons LIST is a bottom-nav tab (inside the ShellRoute below);
      // its detail page stays top-level/full-screen, same "tab root inside
      // the shell, detail pushed on top" split every other tab already
      // follows implicitly by having no sub-routes at all.
      GoRoute(
        path: '$_couponsPath/:id',
        builder: (context, state) => CouponDetailScreen(couponId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: _luckyDrawPath, builder: (context, state) => const DrawsListScreen()),
      // /my-wins and /vouchers/:id registered before /:id below -- same
      // same-segment-count collision precedent as /purchases/scan.
      GoRoute(path: '$_luckyDrawPath/my-wins', builder: (context, state) => const MyVouchersScreen()),
      GoRoute(
        path: '$_luckyDrawPath/vouchers/:id',
        builder: (context, state) => VoucherDetailScreen(voucherId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '$_luckyDrawPath/:id',
        builder: (context, state) => DrawDetailScreen(drawId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/redeem', builder: (context, state) => const RedeemOffersScreen()),
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
      // Pushed from the Home header's bell icon now (see HomeHeader), not a
      // bottom-nav tab -- top-level like /wallet's own sub-pages, not inside
      // the ShellRoute below.
      GoRoute(path: _notificationsPath, builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: _merchantsPath, builder: (context, state) => MerchantsListScreen(initialCategoryId: state.extra as int?)),
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
          GoRoute(path: _walletPath, builder: (context, state) => const WalletScreen()),
          GoRoute(path: _couponsPath, builder: (context, state) => const CouponsListScreen()),
          GoRoute(path: _profilePath, builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

String? _redirect(AuthState authState, String location) {
  final onSplash = location == _splashPath;
  final onLogin = location == _loginPath;
  final onRegister = location == _registerPath;
  final onProtected = !onSplash && !onLogin && !onRegister;

  return switch (authState) {
    AuthInitial() => onSplash ? null : _splashPath,
    AuthUnauthenticated() || AuthSessionExpired() => (onLogin || onRegister) ? null : _loginPath,
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
