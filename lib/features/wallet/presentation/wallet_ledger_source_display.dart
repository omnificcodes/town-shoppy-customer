import 'package:flutter/material.dart';

/// Human label + icon for each `LedgerSource` value
/// (`App\Domain\Wallet\Enums\LedgerSource`). Only `purchase_reward` and
/// `admin_adjustment` are actually issuable today (per that enum's own
/// docblock) -- the rest are mapped now so a future credit path (Referral/
/// Subscription/Campaign) never falls back to a raw snake_case string.
class WalletLedgerSourceDisplay {
  const WalletLedgerSourceDisplay(this.label, this.icon);

  final String label;
  final IconData icon;

  static const _byline = <String, WalletLedgerSourceDisplay>{
    'purchase_reward': WalletLedgerSourceDisplay('Purchase reward', Icons.storefront_rounded),
    'referral_reward': WalletLedgerSourceDisplay('Referral reward', Icons.people_alt_rounded),
    'promotional_reward': WalletLedgerSourceDisplay('Promotional bonus', Icons.celebration_rounded),
    'subscription_reward': WalletLedgerSourceDisplay('Subscription bonus', Icons.workspace_premium_rounded),
    'campaign_reward': WalletLedgerSourceDisplay('Campaign reward', Icons.campaign_rounded),
    'admin_adjustment': WalletLedgerSourceDisplay('Adjustment', Icons.tune_rounded),
    'redemption_debit': WalletLedgerSourceDisplay('Redeemed', Icons.qr_code_2_rounded),
    // Blue Coin the customer's own business earned, mirrored here so it
    // can be spent in Customer mode (BlueCoinMirrorService on the API).
    'business_blue_coin': WalletLedgerSourceDisplay('Blue Coin from your business', Icons.store_rounded),
  };

  static const _fallback = WalletLedgerSourceDisplay('Town Coin activity', Icons.swap_horiz_rounded);

  static WalletLedgerSourceDisplay forSource(String source) => _byline[source] ?? _fallback;
}
