import 'package:flutter/material.dart';

import '../data/models/nearby_merchant.dart';
import 'merchant_card.dart';

/// A `GET /merchants/nearby` result: the same [MerchantCard], but showing
/// the matching branch's area and its distance instead of the primary
/// branch's -- what a "near me" list is for.
class NearbyMerchantCard extends StatelessWidget {
  const NearbyMerchantCard({super.key, required this.result, this.onTap});

  final NearbyMerchant result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final branch = result.branch;

    return MerchantCard(
      merchant: result.merchant,
      onTap: onTap,
      distanceKm: result.distanceKm,
      place: branch.locality ?? branch.city,
    );
  }
}
