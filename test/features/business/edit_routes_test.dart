import 'dart:async';

import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_offers_controller.dart';
import 'package:customer/features/business/application/business_branches_controller.dart';
import 'package:customer/features/business/data/models/merchant_branch.dart';
import 'package:customer/features/business/presentation/branches/branch_form_screen.dart';
import 'package:customer/features/business/presentation/products/product_form_screen.dart';
import 'package:customer/features/products/application/products_list_controller.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:customer/features/business/data/models/business_offer.dart';
import 'package:customer/features/business/presentation/offers/offer_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every `/edit` route in Business mode used to take its entity from
/// GoRouter's `extra`, which is in-memory only. Reloading the page on the
/// hosted web build dropped it, and the route silently rendered an empty
/// CREATE form -- so saving made a second record instead of editing the one
/// the URL named. These pin the id as the thing each screen loads from.
BusinessOffer _offer({String status = 'active'}) => BusinessOffer.fromJson({
  'id': 7,
  'title': 'Sunday offer',
  'description': 'Half price on Sundays.',
  'offer_type': 'percentage_discount',
  'status': status,
  'starts_at': '2026-09-01T10:00:00+05:30',
  'ends_at': '2026-12-01T10:00:00+05:30',
});

Widget _app({BusinessOffer? initial, required Future<BusinessOffer> Function() load}) {
  return ProviderScope(
    overrides: [businessOfferProvider(7).overrideWith((ref) => load())],
    child: MaterialApp(
      theme: AppTheme.light,
      home: EditOfferScreen(offerId: 7, initial: initial),
    ),
  );
}

const _lockNote = 'Fixed — this offer has already started.';

void main() {
  _branchTests();
  _productTests();

  testWidgets('loads the offer by id when the route carries no extra -- a reloaded edit URL', (tester) async {
    await tester.pumpWidget(_app(initial: null, load: () async => _offer()));
    await tester.pumpAndSettle();

    expect(find.text('Edit offer'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Sunday offer'), findsOneWidget);
    // Never the create form -- that is the bug this guards.
    expect(find.text('New offer'), findsNothing);
    expect(find.text('Save as draft'), findsNothing);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('shows the offer straight away when the list handed one over', (tester) async {
    // Never resolves: proves the first frame came from `initial`, not the fetch.
    await tester.pumpWidget(_app(initial: _offer(), load: () => Completer<BusinessOffer>().future));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Sunday offer'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry instead of an empty create form', (tester) async {
    await tester.pumpWidget(_app(initial: null, load: () async => throw const NetworkException()));
    await tester.pumpAndSettle();

    expect(find.text('Could not load this offer'), findsOneWidget);
    expect(find.text('New offer'), findsNothing);
  });

  testWidgets('the start date of a live offer is locked, since it has already started', (tester) async {
    await tester.pumpWidget(_app(initial: null, load: () async => _offer()));
    await tester.pumpAndSettle();

    // The Schedule section sits below the fold of a lazy ListView, so it
    // only exists once scrolled to.
    await tester.scrollUntilVisible(find.text(_lockNote), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(_lockNote), findsOneWidget);
  });

  testWidgets('the start date of a draft is still free to move', (tester) async {
    await tester.pumpWidget(_app(initial: null, load: () async => _offer(status: 'draft')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Starts'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(_lockNote), findsNothing);
  });
}

void _branchTests() {
  MerchantBranch branch(int id) => MerchantBranch.fromJson({
    'id': id,
    'merchant_id': 5,
    'name': 'Calicut Branch',
    'is_primary': true,
    'address_line': '12 Beach Road',
    'locality': 'Kozhikode',
    'city': 'Kozhikode',
    'status': 'active',
  });

  Widget app({MerchantBranch? initial, required List<MerchantBranch> list}) => ProviderScope(
    overrides: [businessBranchesControllerProvider.overrideWith(() => _FakeBranchesController(list))],
    child: MaterialApp(theme: AppTheme.light, home: EditBranchScreen(branchId: 3, initial: initial)),
  );

  testWidgets('branch edit loads by id when the route carries no extra', (tester) async {
    await tester.pumpWidget(app(initial: null, list: [branch(3)]));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Calicut Branch'), findsOneWidget);
    expect(find.text('New branch'), findsNothing);
  });

  testWidgets('branch edit refuses to become a create form when the id is gone', (tester) async {
    await tester.pumpWidget(app(initial: null, list: [branch(99)]));
    await tester.pumpAndSettle();

    expect(find.text('Branch not found'), findsOneWidget);
    expect(find.text('New branch'), findsNothing);
  });
}

void _productTests() {
  Product product() => Product.fromJson({
    'id': 4,
    'name': 'Assorted Cupcakes',
    'price': 250,
    'status': 'inactive',
  });

  Widget app({Product? initial, required Future<Product> Function() load}) => ProviderScope(
    overrides: [productDetailProvider(4).overrideWith((ref) => load())],
    child: MaterialApp(theme: AppTheme.light, home: EditProductScreen(productId: 4, initial: initial)),
  );

  testWidgets('product edit loads by id when the route carries no extra, even for an inactive product', (tester) async {
    await tester.pumpWidget(app(initial: null, load: () async => product()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Assorted Cupcakes'), findsOneWidget);
    expect(find.text('New product'), findsNothing);
  });

  testWidgets('product edit offers a retry instead of an empty create form when the load fails', (tester) async {
    await tester.pumpWidget(app(initial: null, load: () async => throw const NetworkException()));
    await tester.pumpAndSettle();

    expect(find.text('Could not load this product'), findsOneWidget);
    expect(find.text('New product'), findsNothing);
  });
}

class _FakeBranchesController extends BusinessBranchesController {
  _FakeBranchesController(this._list);

  final List<MerchantBranch> _list;

  @override
  Future<List<MerchantBranch>> build() async => _list;
}
