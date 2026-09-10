import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
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
import '../../features/offer_redemptions/presentation/offer_redeem_screen.dart';
import '../../features/offer_redemptions/presentation/offer_redemption_detail_screen.dart';
import '../../features/offer_redemptions/presentation/offer_redemptions_list_screen.dart';
import '../../features/offers/presentation/offers_list_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
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
const _forgotPasswordPath = '/forgot-password';
const _resetPasswordPath = '/reset-password';
const _homePath = '/home';
const _walletPath = '/wallet';
const _offersPath = '/offers';
const _notificationsPath = '/notifications';
const _profilePath = '/profile';
const _purchasesPath = '/purchases';
const _couponsPath = '/coupons';
const _luckyDrawPath = '/lucky-draw';
const _redemptionsPath = '/redemptions';
const _offerRedemptionsPath = '/offer-redemptions';
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
      GoRoute(path: _forgotPasswordPath, builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: _resetPasswordPath,
        builder: (context, state) => ResetPasswordScreen(args: state.extra as ResetPasswordArgs),
      ),
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
        // Keyed by id so navigating from one purchase's detail page straight
        // to another's (e.g. via a notification) discards the old State --
        // otherwise Flutter reuses it and the celebration/polling flags from
        // the previous purchase leak into the new one.
        builder: (context, state) => PurchaseDetailScreen(
          key: ValueKey('purchase-${state.pathParameters['id']}'),
          purchaseId: int.parse(state.pathParameters['id']!),
        ),
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
      // Coin Economy V2 (coin-economy-v2.md §6.2) -- `/offers/:id/redeem`
      // registered near the merchant `/redeem` sub-route above it, not
      // inside the ShellRoute (a full-screen form, same as
      // RedemptionInitiationScreen).
      GoRoute(
        path: '/offers/:id/redeem',
        builder: (context, state) => OfferRedeemScreen(offerId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: _offerRedemptionsPath, builder: (context, state) => const OfferRedemptionsListScreen()),
      GoRoute(
        path: '$_offerRedemptionsPath/:id',
        builder: (context, state) =>
            OfferRedemptionDetailScreen(offerRedemptionId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: _referralsPath, builder: (context, state) => const ReferralScreen()),
      // Pushed from the Home header's bell icon now (see HomeHeader), not a
      // bottom-nav tab -- top-level, not inside the ShellRoute below.
      GoRoute(path: _notificationsPath, builder: (context, state) => const NotificationsScreen()),
      // Wallet went through the same tab -> top-level-push demotion once
      // Offers took its bottom-nav slot (see AppShell's docblock) -- still
      // pushed from Home's wallet card, just no longer inside the
      // ShellRoute below.
      GoRoute(path: _walletPath, builder: (context, state) => const WalletScreen()),
      GoRoute(path: _merchantsPath, builder: (context, state) => MerchantsListScreen(initialCategoryId: state.extra as int?)),
      GoRoute(
        path: '$_merchantsPath/:id',
        builder: (context, state) => MerchantDetailScreen(merchantId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '$_merchantsPath/:id/redeem',
        builder: (context, state) => RedemptionInitiationScreen(merchantId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '$_profilePath/edit', builder: (context, state) => const EditProfileScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: _homePath, builder: (context, state) => const HomeScreen()),
          GoRoute(path: _offersPath, builder: (context, state) => const OffersListScreen()),
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
  final onForgotPassword = location == _forgotPasswordPath;
  final onResetPassword = location == _resetPasswordPath;
  final onPublicAuthRoute = onLogin || onRegister || onForgotPassword || onResetPassword;
  final onProtected = !onSplash && !onPublicAuthRoute;

  return switch (authState) {
    AuthInitial() => onSplash ? null : _splashPath,
    AuthUnauthenticated() || AuthSessionExpired() => onPublicAuthRoute ? null : _loginPath,
    AuthAuthenticated() => onProtected ? null : _homePath,
  };
}

/// Shown while [AuthController] restores a stored session on cold start.
/// Branded (cream ground + logo) so the first frame is Town Shoppy, not a
/// bare spinner; the indicator only appears after a short delay so a fast
/// restore never flashes one at all.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/townshoppy_logo.png',
              height: 96,
              semanticLabel: 'Town Shoppy',
              color: AppColors.surfaceMuted,
              colorBlendMode: BlendMode.multiply,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _DelayedIndicator(),
          ],
        ),
      ),
    );
  }
}

class _DelayedIndicator extends StatefulWidget {
  const _DelayedIndicator();

  @override
  State<_DelayedIndicator> createState() => _DelayedIndicatorState();
}

class _DelayedIndicatorState extends State<_DelayedIndicator> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
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
