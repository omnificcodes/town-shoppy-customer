import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_mode/app_mode.dart';
import '../app_mode/app_mode_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/data/models/account.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/business/data/models/merchant_branch.dart';
import '../../features/business/presentation/billing/business_invoice_detail_screen.dart';
import '../../features/business/presentation/billing/business_invoices_screen.dart';
import '../../features/business/presentation/billing/business_payment_detail_screen.dart';
import '../../features/business/presentation/billing/business_payments_screen.dart';
import '../../features/business/presentation/branches/branch_form_screen.dart';
import '../../features/business/presentation/branches/branch_qr_screen.dart';
import '../../features/business/presentation/branches/business_branches_screen.dart';
import '../../features/business/presentation/business_dashboard_screen.dart';
import '../../features/business/presentation/business_qr_scan_screen.dart';
import '../../features/business/presentation/customers/business_customer_detail_screen.dart';
import '../../features/business/presentation/customers/business_customers_screen.dart';
import '../../features/business/data/models/business_offer.dart';
import '../../features/business/presentation/offers/business_offer_detail_screen.dart';
import '../../features/business/presentation/offers/business_offers_screen.dart';
import '../../features/business/presentation/offers/offer_form_screen.dart';
import '../../features/business/presentation/offers/offer_redemptions_screen.dart';
import '../../features/business/presentation/prizes/business_prize_detail_screen.dart';
import '../../features/business/presentation/prizes/business_prizes_screen.dart';
import '../../features/business/presentation/prizes/prize_form_screen.dart';
import '../../features/business/presentation/products/business_products_screen.dart';
import '../../features/business/presentation/products/product_form_screen.dart';
import '../../features/business/presentation/wallet/merchant_wallet_screen.dart';
import '../../features/business/presentation/direct_pos/direct_pos_screen.dart';
import '../../features/business/presentation/purchases/business_purchase_detail_screen.dart';
import '../../features/business/presentation/purchases/business_purchases_screen.dart';
import '../../features/business/presentation/redemptions/business_redemption_detail_screen.dart';
import '../../features/business/presentation/redemptions/business_redemptions_screen.dart';
import '../../features/redemptions/data/models/redemption.dart';
import '../../features/business/presentation/business_more_screen.dart';
import '../../features/business/presentation/business_profile_screen.dart';
import '../../features/business/presentation/business_routes.dart';
import '../../features/business/presentation/business_security_screen.dart';
import '../../features/business/presentation/business_shell.dart';
import '../../features/business/presentation/business_subscriptions_screen.dart';
import '../../features/business/presentation/edit_business_profile_screen.dart';
import '../../features/business/presentation/merchant_register_screen.dart';
import '../../features/business/presentation/mode_chooser_screen.dart';
import '../../features/business/presentation/package_gate.dart';
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
import '../../features/products/data/models/product.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/products/presentation/products_list_screen.dart';
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
const _registerMerchantPath = '/register-merchant';
const _forgotPasswordPath = '/forgot-password';
const _resetPasswordPath = '/reset-password';
const _chooseModePath = '/choose-mode';
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
const _shoppingPath = '/shopping';
const _productsPath = '/products';

/// Auth-aware [GoRouter]. Redirect logic — not widget-level checks — is the
/// single source of truth for "who can see what" (section 13: "do not rely
/// only on widget-level redirects"). That now includes *which mode* an
/// account is in: Customer routes and `/business/*` routes are mutually
/// exclusive trees, and the remembered [AppMode] decides which one is open.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: _splashPath,
    refreshListenable: notifier,
    redirect: (context, state) => _redirect(
      ref.read(authControllerProvider),
      ref.read(appModeControllerProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(path: _splashPath, builder: (context, state) => const _SplashScreen()),
      GoRoute(path: _loginPath, builder: (context, state) => const LoginScreen()),
      GoRoute(path: _registerPath, builder: (context, state) => const RegisterScreen()),
      // Reachable signed-out (from Login) AND signed-in (from the drawer /
      // Profile) -- the screen itself decides whether to ask for a password.
      GoRoute(path: _registerMerchantPath, builder: (context, state) => const MerchantRegisterScreen()),
      GoRoute(path: _forgotPasswordPath, builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: _resetPasswordPath,
        builder: (context, state) => ResetPasswordScreen(args: state.extra as ResetPasswordArgs),
      ),
      GoRoute(path: _chooseModePath, builder: (context, state) => const ModeChooserScreen()),
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
        path: _shoppingPath,
        // Pushed from the merchant detail page's Products section "See
        // all" with `extra: (merchantId, merchantName)` to scope this same
        // screen to one merchant; the drawer's own entry pushes it with no
        // `extra` for the global catalog.
        builder: (context, state) {
          final scope = state.extra as (int, String)?;
          return ProductsListScreen(merchantId: scope?.$1, merchantName: scope?.$2);
        },
      ),
      // Standalone/top-level (not the ShellRoute below) and carved out of
      // the login gate in `_redirect` -- its whole purpose is to also open
      // for a merchant who taps this link from a WhatsApp order message on
      // a device that may not be signed in at all. See ProductDetailScreen's
      // own docblock.
      GoRoute(
        path: '$_productsPath/:id',
        builder: (context, state) => ProductDetailScreen(productId: int.parse(state.pathParameters['id']!)),
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

      // ---------------------------------------------------------------
      // Business mode. Same "tab roots inside the shell, everything else
      // pushed on top" split as the customer tree. Package-gated
      // destinations are wrapped in RequirePackage here, at the route, so
      // no screen can forget to gate itself.
      // ---------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) => BusinessShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: BusinessRoutes.root, builder: (context, state) => const BusinessDashboardScreen()),
          GoRoute(
            path: BusinessRoutes.purchases,
            builder: (context, state) => const RequirePackage(feature: 'Purchases', child: BusinessPurchasesScreen()),
          ),
          GoRoute(
            path: BusinessRoutes.offers,
            builder: (context, state) => const RequirePackage(feature: 'Offers', child: BusinessOffersScreen()),
          ),
          GoRoute(path: BusinessRoutes.more, builder: (context, state) => const BusinessMoreScreen()),
        ],
      ),
      // Purchase detail is pushed on top of the Sales tab (outside the
      // shell) so the bottom bar's Approve/Reject never fights the nav bar.
      GoRoute(
        path: '${BusinessRoutes.purchases}/:id',
        builder: (context, state) => RequirePackage(
          feature: 'Purchases',
          child: BusinessPurchaseDetailScreen(
            key: ValueKey('business-purchase-${state.pathParameters['id']}'),
            purchaseId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.counter,
        builder: (context, state) => const RequirePackage(feature: 'Direct POS', child: DirectPosScreen()),
      ),
      // The camera scanner pops with the decoded string; the caller decides
      // what it means (customer identity QR at the counter, a redemption
      // QR during verification).
      GoRoute(
        path: BusinessRoutes.scan,
        builder: (context, state) => BusinessQrScanScreen(args: state.extra as BusinessScanArgs? ?? BusinessScanArgs.customerQr),
      ),
      GoRoute(
        path: BusinessRoutes.branches,
        builder: (context, state) => const RequirePackage(feature: 'Your branches', child: BusinessBranchesScreen()),
      ),
      // `/new` before `/:id/...` so "new" is never parsed as an id.
      GoRoute(
        path: BusinessRoutes.branchNew,
        builder: (context, state) => const RequirePackage(feature: 'Your branches', child: BranchFormScreen()),
      ),
      GoRoute(
        path: '${BusinessRoutes.branches}/:id/edit',
        builder: (context, state) => RequirePackage(
          feature: 'Your branches',
          child: BranchFormScreen(key: ValueKey('branch-edit-${state.pathParameters['id']}'), branch: state.extra as MerchantBranch?),
        ),
      ),
      GoRoute(
        path: '${BusinessRoutes.branches}/:id/qr',
        builder: (context, state) => RequirePackage(
          feature: 'Your branches',
          child: BranchQrScreen(branchId: int.parse(state.pathParameters['id']!), branch: state.extra as MerchantBranch?),
        ),
      ),
      // `/new` before `/:id` so "new" is never parsed as an id.
      GoRoute(
        path: BusinessRoutes.offerNew,
        builder: (context, state) => const RequirePackage(feature: 'Offers', child: OfferFormScreen()),
      ),
      GoRoute(
        path: '${BusinessRoutes.offers}/:id',
        builder: (context, state) => RequirePackage(
          feature: 'Offers',
          child: BusinessOfferDetailScreen(key: ValueKey('offer-${state.pathParameters['id']}'), offerId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '${BusinessRoutes.offers}/:id/edit',
        builder: (context, state) => RequirePackage(
          feature: 'Offers',
          child: OfferFormScreen(key: ValueKey('offer-edit-${state.pathParameters['id']}'), offer: state.extra as BusinessOffer?),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.products,
        builder: (context, state) => const RequirePackage(feature: 'Products', child: BusinessProductsScreen()),
      ),
      // `/new` before `/:id/edit` so "new" is never parsed as an id.
      GoRoute(
        path: BusinessRoutes.productNew,
        builder: (context, state) => const RequirePackage(feature: 'Products', child: ProductFormScreen()),
      ),
      GoRoute(
        path: '${BusinessRoutes.products}/:id/edit',
        builder: (context, state) => RequirePackage(
          feature: 'Products',
          child: ProductFormScreen(key: ValueKey('product-edit-${state.pathParameters['id']}'), product: state.extra as Product?),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.customers,
        builder: (context, state) => const RequirePackage(feature: 'Your customer directory', child: BusinessCustomersScreen()),
      ),
      GoRoute(
        path: '${BusinessRoutes.customers}/:id',
        builder: (context, state) => RequirePackage(
          feature: 'Your customer directory',
          child: BusinessCustomerDetailScreen(key: ValueKey('customer-${state.pathParameters['id']}'), customerId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.redemptions,
        builder: (context, state) => const RequirePackage(feature: 'Town Coin redemptions', child: BusinessRedemptionsScreen()),
      ),
      GoRoute(
        path: '${BusinessRoutes.redemptions}/:id',
        builder: (context, state) => RequirePackage(
          feature: 'Town Coin redemptions',
          child: BusinessRedemptionDetailScreen(
            key: ValueKey('business-redemption-${state.pathParameters['id']}'),
            redemptionId: int.parse(state.pathParameters['id']!),
            listRow: state.extra as Redemption?,
          ),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.offerRedemptions,
        builder: (context, state) => const RequirePackage(feature: 'Offer redemptions', child: OfferRedemptionsScreen()),
      ),
      GoRoute(
        path: BusinessRoutes.wallet,
        builder: (context, state) => const RequirePackage(feature: 'Your merchant wallet', child: MerchantWalletScreen()),
      ),
      GoRoute(
        path: BusinessRoutes.prizes,
        builder: (context, state) => const RequirePackage(feature: 'Sponsored prizes', child: BusinessPrizesScreen()),
      ),
      GoRoute(
        path: BusinessRoutes.prizeNew,
        builder: (context, state) => const RequirePackage(feature: 'Sponsored prizes', child: PrizeFormScreen()),
      ),
      GoRoute(
        path: '${BusinessRoutes.prizes}/:id',
        builder: (context, state) => RequirePackage(
          feature: 'Sponsored prizes',
          child: BusinessPrizeDetailScreen(key: ValueKey('prize-${state.pathParameters['id']}'), prizeId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(path: BusinessRoutes.payments, builder: (context, state) => const BusinessPaymentsScreen()),
      GoRoute(
        path: '${BusinessRoutes.payments}/:id',
        builder: (context, state) => BusinessPaymentDetailScreen(key: ValueKey('payment-${state.pathParameters['id']}'), paymentId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: BusinessRoutes.subscriptions, builder: (context, state) => const BusinessSubscriptionsScreen()),
      GoRoute(path: BusinessRoutes.invoices, builder: (context, state) => const BusinessInvoicesScreen()),
      GoRoute(
        path: '${BusinessRoutes.invoices}/:id',
        builder: (context, state) => BusinessInvoiceDetailScreen(key: ValueKey('invoice-${state.pathParameters['id']}'), invoiceId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: BusinessRoutes.profile, builder: (context, state) => const BusinessProfileScreen()),
      GoRoute(path: BusinessRoutes.profileEdit, builder: (context, state) => const EditBusinessProfileScreen()),
      // Notifications are account-scoped, so the customer screen is the
      // business screen too -- one inbox, two entry points.
      GoRoute(path: BusinessRoutes.notifications, builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: BusinessRoutes.security, builder: (context, state) => const BusinessSecurityScreen()),
      GoRoute(path: BusinessRoutes.securityPassword, builder: (context, state) => const BusinessPasswordScreen()),
    ],
  );
});

String? _redirect(AuthState authState, AppModeState modeState, String location) {
  // A product's own detail page is the one deliberately public route in
  // this app -- it must open for anyone who taps its link from a WhatsApp
  // order message (see ProductDetailScreen's docblock), regardless of auth
  // state, and regardless of which state [authState] is currently in (a
  // fresh web load lands here with AuthInitial() while session restore is
  // still in flight -- this check must win over every branch below, not
  // just the Unauthenticated one).
  if (location.startsWith('$_productsPath/')) return null;

  final onSplash = location == _splashPath;
  final onLogin = location == _loginPath;
  final onRegister = location == _registerPath;
  final onRegisterMerchant = location == _registerMerchantPath;
  final onForgotPassword = location == _forgotPasswordPath;
  final onResetPassword = location == _resetPasswordPath;
  final onPublicAuthRoute = onLogin || onRegister || onRegisterMerchant || onForgotPassword || onResetPassword;
  final onProtected = !onSplash && !onPublicAuthRoute;

  return switch (authState) {
    AuthInitial() => onSplash ? null : _splashPath,
    AuthUnauthenticated() || AuthSessionExpired() => onPublicAuthRoute ? null : _loginPath,
    AuthAuthenticated(:final account) => _redirectAuthenticated(
        account,
        modeState,
        location,
        onSplash: onSplash,
        onProtected: onProtected,
        onRegisterMerchant: onRegisterMerchant,
      ),
  };
}

/// Signed-in routing. Three trees exist -- Customer, Business, and the
/// small shared set (chooser, merchant registration) -- and the remembered
/// mode picks between the first two:
///
/// * no merchant profile  -> Customer tree only; `/business/*` and the
///   chooser bounce to Home (mode is irrelevant).
/// * merchant, no choice  -> the chooser, and nothing else.
/// * merchant, Business   -> `/business/*` only.
/// * merchant, Customer   -> Customer tree only.
String? _redirectAuthenticated(
  Account account,
  AppModeState modeState,
  String location, {
  required bool onSplash,
  required bool onProtected,
  required bool onRegisterMerchant,
}) {
  // Reachable from both modes and from the Login screen; the screen
  // itself adapts to "already signed in".
  if (onRegisterMerchant) return null;

  final onBusiness = location == BusinessRoutes.root || location.startsWith('${BusinessRoutes.root}/');
  final onChooser = location == _chooseModePath;

  if (!account.hasMerchantAccess) {
    if (onBusiness || onChooser) return _homePath;
    return onProtected ? null : _homePath;
  }

  // The saved mode is read from disk asynchronously; until it's known the
  // splash stays up rather than flashing the chooser at a returning owner.
  if (!modeState.loaded) return onSplash ? null : _splashPath;

  final mode = modeState.mode;
  if (mode == null) return onChooser ? null : _chooseModePath;
  if (onChooser) return null; // explicit "switch mode" visit from a menu

  return switch (mode) {
    AppMode.business => onBusiness ? null : BusinessRoutes.root,
    AppMode.customer => onBusiness ? _homePath : (onProtected ? null : _homePath),
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

/// Bridges Riverpod's [authControllerProvider] and [appModeControllerProvider]
/// to go_router's [Listenable]-based `refreshListenable`, so a state change
/// (login, logout, session expiry, mode switch) immediately re-evaluates
/// [_redirect] instead of only on the next navigation event.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _authSubscription = ref.listen<AuthState>(authControllerProvider, (previous, next) => notifyListeners());
    _modeSubscription = ref.listen<AppModeState>(appModeControllerProvider, (previous, next) => notifyListeners());
  }

  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<AppModeState> _modeSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _modeSubscription.close();
    super.dispose();
  }
}
