import 'package:flutter/material.dart';

/// Every Business-mode path in one place. The router, the shell's tabs and
/// the "More" hub all read from here so a path is never typed twice.
class BusinessRoutes {
  BusinessRoutes._();

  static const root = '/business';
  static const purchases = '/business/purchases';
  static const counter = '/business/counter';
  static const offers = '/business/offers';
  static const offerNew = '/business/offers/new';
  static const more = '/business/more';

  static const branches = '/business/branches';
  static const branchNew = '/business/branches/new';
  static const customers = '/business/customers';
  static const redemptions = '/business/redemptions';
  static const offerRedemptions = '/business/offer-redemptions';
  static const wallet = '/business/wallet';
  static const prizes = '/business/prizes';
  static const prizeNew = '/business/prizes/new';
  static const payments = '/business/payments';
  static const subscriptions = '/business/subscriptions';
  static const invoices = '/business/invoices';
  static const profile = '/business/profile';
  static const profileEdit = '/business/profile/edit';
  static const notifications = '/business/notifications';
  static const security = '/business/security';
  static const securityPassword = '/business/security/password';

  /// Generic camera scanner; pushed with a [BusinessScanArgs] `extra` and
  /// pops with the decoded string.
  static const scan = '/business/scan';

  /// The four bottom-nav roots, in tab order.
  static const tabs = [root, purchases, offers, more];
}

/// One entry of the merchant navigation -- the same list, grouping,
/// Owner/Staff visibility and package-lock rule as the merchant web app's
/// `merchantNav(isOwner)` + `MERCHANT_PACKAGE_LOCKED_PREFIXES`.
class BusinessDestination {
  const BusinessDestination({
    required this.label,
    required this.icon,
    required this.path,
    required this.group,
    this.subtitle,
    this.gated = false,
    this.ownerOnly = false,
  });

  final String label;
  final IconData icon;
  final String path;
  final String group;
  final String? subtitle;

  /// Locked until the shop is on a package (`RequireActivePackage`).
  final bool gated;

  /// Hidden from Merchant Staff entirely.
  final bool ownerOnly;

  static const all = <BusinessDestination>[
    BusinessDestination(label: 'Dashboard', icon: Icons.space_dashboard_rounded, path: BusinessRoutes.root, group: 'Overview'),
    BusinessDestination(label: 'Branches', icon: Icons.location_on_rounded, path: BusinessRoutes.branches, group: 'Business', subtitle: 'Locations and counter QR', gated: true),
    BusinessDestination(label: 'Customers', icon: Icons.people_alt_rounded, path: BusinessRoutes.customers, group: 'Business', subtitle: 'Everyone who shopped with you', gated: true),
    BusinessDestination(label: 'Purchases', icon: Icons.shopping_bag_rounded, path: BusinessRoutes.purchases, group: 'Business', subtitle: 'Bills recorded and awaiting approval', gated: true),
    BusinessDestination(label: 'Direct POS', icon: Icons.point_of_sale_rounded, path: BusinessRoutes.counter, group: 'Business', subtitle: 'Record a bill at the counter', gated: true),
    BusinessDestination(label: 'Redemptions', icon: Icons.qr_code_2_rounded, path: BusinessRoutes.redemptions, group: 'Business', subtitle: 'Verify Town Coin spent here', gated: true),
    BusinessDestination(label: 'Offers', icon: Icons.campaign_rounded, path: BusinessRoutes.offers, group: 'Business', subtitle: 'Promotions shown to your town', gated: true),
    BusinessDestination(label: 'Offer redemptions', icon: Icons.redeem_rounded, path: BusinessRoutes.offerRedemptions, group: 'Business', subtitle: 'Customers claiming your offers', gated: true),
    BusinessDestination(label: 'Wallet', icon: Icons.account_balance_wallet_rounded, path: BusinessRoutes.wallet, group: 'Wallet', subtitle: 'Blue and Red coin balances', gated: true),
    BusinessDestination(label: 'Sponsored prizes', icon: Icons.emoji_events_rounded, path: BusinessRoutes.prizes, group: 'Lucky Draw', subtitle: 'Put your brand on a draw', gated: true, ownerOnly: true),
    BusinessDestination(label: 'Payments', icon: Icons.credit_card_rounded, path: BusinessRoutes.payments, group: 'Finances', ownerOnly: true),
    BusinessDestination(label: 'Subscriptions', icon: Icons.workspace_premium_rounded, path: BusinessRoutes.subscriptions, group: 'Finances', subtitle: 'Your package and plan', ownerOnly: true),
    BusinessDestination(label: 'Invoices', icon: Icons.description_rounded, path: BusinessRoutes.invoices, group: 'Finances', ownerOnly: true),
    BusinessDestination(label: 'Business profile', icon: Icons.storefront_rounded, path: BusinessRoutes.profile, group: 'Account', subtitle: 'What customers see about you'),
    BusinessDestination(label: 'Notifications', icon: Icons.notifications_rounded, path: BusinessRoutes.notifications, group: 'Account'),
    BusinessDestination(label: 'Security', icon: Icons.key_rounded, path: BusinessRoutes.security, group: 'Account', subtitle: 'Password and sign-in'),
  ];

  static const groupOrder = ['Business', 'Wallet', 'Lucky Draw', 'Finances', 'Account'];

  static bool isGatedPath(String path) => all.any((d) => d.gated && (path == d.path || path.startsWith('${d.path}/')));
}
