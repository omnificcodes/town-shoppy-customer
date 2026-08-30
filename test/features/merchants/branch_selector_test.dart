import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/presentation/branch_selector.dart';

import '../../helpers/responsive_test_helper.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('shows an empty state when there are no branches', (tester) async {
    await tester.pumpWidget(_wrap(const BranchSelector(branches: [])));

    expect(find.text('No branch information available'), findsOneWidget);
  });

  testWidgets('renders the branch name and formatted address, never opening hours', (tester) async {
    const branch = MerchantBranchRef(
      id: 1,
      name: 'Downtown Branch',
      isPrimary: false,
      addressLine: 'MG Road',
      locality: null,
      city: 'Springfield',
      state: null,
      postalCode: null,
      country: null,
      latitude: 1.0,
      longitude: 2.0,
      distanceKm: null,
    );

    await tester.pumpWidget(_wrap(const BranchSelector(branches: [branch])));

    expect(find.text('Downtown Branch'), findsOneWidget);
    expect(find.text('MG Road, Springfield'), findsOneWidget);
    expect(find.textContaining('AM'), findsNothing);
    expect(find.textContaining('PM'), findsNothing);
  });

  testWidgets('renders as a non-interactive info card when onSelected is null', (tester) async {
    const branch = MerchantBranchRef(
      id: 1,
      name: 'Downtown Branch',
      isPrimary: false,
      addressLine: null,
      locality: null,
      city: null,
      state: null,
      postalCode: null,
      country: null,
      latitude: 1.0,
      longitude: 2.0,
      distanceKm: null,
    );

    await tester.pumpWidget(_wrap(const BranchSelector(branches: [branch])));

    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);
    expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
  });

  testWidgets('invokes onSelected with the tapped branch id when interactive', (tester) async {
    const branch = MerchantBranchRef(
      id: 42,
      name: 'Downtown Branch',
      isPrimary: false,
      addressLine: null,
      locality: null,
      city: null,
      state: null,
      postalCode: null,
      country: null,
      latitude: 1.0,
      longitude: 2.0,
      distanceKm: null,
    );
    int? selectedId;

    await tester.pumpWidget(_wrap(BranchSelector(branches: const [branch], onSelected: (id) => selectedId = id)));
    await tester.tap(find.text('Downtown Branch'));

    expect(selectedId, 42);
  });

  testWidgets('labels the primary branch only when there is more than one branch', (tester) async {
    const primary = MerchantBranchRef(
      id: 1,
      name: 'Main Street',
      isPrimary: true,
      addressLine: null,
      locality: null,
      city: null,
      state: null,
      postalCode: null,
      country: null,
      latitude: 1.0,
      longitude: 2.0,
      distanceKm: null,
    );
    const secondary = MerchantBranchRef(
      id: 2,
      name: 'City Centre',
      isPrimary: false,
      addressLine: null,
      locality: null,
      city: null,
      state: null,
      postalCode: null,
      country: null,
      latitude: 1.0,
      longitude: 2.0,
      distanceKm: null,
    );

    await tester.pumpWidget(_wrap(const BranchSelector(branches: [primary, secondary])));

    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Main Street'), findsOneWidget);
    expect(find.text('City Centre'), findsOneWidget);
  });

  testWidgets('does not label a lone branch as Primary, even when is_primary is true', (tester) async {
    const branch = MerchantBranchRef(
      id: 1,
      name: 'Main Street',
      isPrimary: true,
      addressLine: null,
      locality: null,
      city: null,
      state: null,
      postalCode: null,
      country: null,
      latitude: 1.0,
      longitude: 2.0,
      distanceKm: null,
    );

    await tester.pumpWidget(_wrap(const BranchSelector(branches: [branch])));

    expect(find.text('Primary'), findsNothing);
  });

  testWidgets('renders a long branch name and address without overflow at every mandated viewport', (tester) async {
    const branches = [
      MerchantBranchRef(
        id: 1,
        name: 'Main Street Flagship Location and Customer Service Centre',
        isPrimary: true,
        addressLine: '1200 West Boulevard Avenue, Suite 450B',
        locality: 'Uptown Financial District',
        city: 'Springfield-on-the-Hudson',
        state: 'New Amsterdam',
        postalCode: '400001',
        country: 'India',
        latitude: 1.0,
        longitude: 2.0,
        distanceKm: null,
      ),
      MerchantBranchRef(
        id: 2,
        name: 'City Centre',
        isPrimary: false,
        addressLine: null,
        locality: null,
        city: null,
        state: null,
        postalCode: null,
        country: null,
        latitude: 1.0,
        longitude: 2.0,
        distanceKm: null,
      ),
    ];

    await forEachViewport(
      tester,
      () => _wrap(const BranchSelector(branches: branches)),
      verify: (tester, size) async {
        expect(find.text('Main Street Flagship Location and Customer Service Centre'), findsOneWidget);
        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('City Centre'), findsOneWidget);
      },
    );
  });
}
