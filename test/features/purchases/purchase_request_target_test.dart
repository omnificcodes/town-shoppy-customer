import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/purchases/data/models/purchase_request_target.dart';

/// GoRouter on web keeps an extra only if it JSON-encodes, and hands the
/// decoded map back on a rebuild. These pin down that every target
/// survives that trip -- the bug was a target that did not, leaving the
/// bill screen with `null` the moment the customer started typing.
void main() {
  final merchant = Merchant.fromJson({
    'id': 42,
    'name': 'Corner Cafe',
    'logo_url': 'https://cdn.example/logo.png',
    'accepts_town_coin': true,
    'discount_rate': 7,
    'branch': {'id': 7, 'name': 'Main Branch', 'address_line': 'MG Road'},
  });

  Object? roundTrip(PurchaseRequestTarget target) => jsonDecode(jsonEncode(target));

  test('a scanned token comes back as the same token', () {
    final back = PurchaseRequestTarget.fromExtra(roundTrip(const PurchaseRequestTarget.scanned('tok_123')));

    expect(back, isA<ScannedPurchaseTarget>().having((t) => t.token, 'token', 'tok_123'));
    expect(back.toRequestJson(), {'token': 'tok_123'});
  });

  test('a merchant from its profile keeps its ids but not the snapshot', () {
    final before = PurchaseRequestTarget.merchant(merchant) as MerchantPurchaseTarget;
    expect(before.merchant, same(merchant));
    expect(before.merchantId, 42);
    expect(before.branchId, 7);

    final back = PurchaseRequestTarget.fromExtra(roundTrip(before)) as MerchantPurchaseTarget;
    expect(back.merchant, isNull);
    expect(back.merchantId, 42);
    expect(back.branchId, 7);
    expect(back.toRequestJson(), {'merchant_id': 42, 'branch_id': 7});
  });

  test('a merchant without a branch sends no branch hint, before or after the trip', () {
    final noBranch = Merchant.fromJson({'id': 9, 'name': 'Kiosk', 'accepts_town_coin': true});
    final before = PurchaseRequestTarget.merchant(noBranch);
    expect(before.toRequestJson(), {'merchant_id': 9});

    final back = PurchaseRequestTarget.fromExtra(roundTrip(before));
    expect(back.toRequestJson(), {'merchant_id': 9});
  });

  test('fromExtra passes a live target straight through and rejects anything else', () {
    const live = PurchaseRequestTarget.scanned('tok');
    expect(PurchaseRequestTarget.fromExtra(live), same(live));

    expect(() => PurchaseRequestTarget.fromExtra(null), throwsArgumentError);
    expect(() => PurchaseRequestTarget.fromExtra('tok'), throwsArgumentError);
    expect(() => PurchaseRequestTarget.fromExtra({'type': 'mystery'}), throwsArgumentError);
  });
}
