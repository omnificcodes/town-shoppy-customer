import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_branches_controller.dart';
import 'package:customer/features/business/data/models/merchant_branch.dart';
import 'package:customer/features/business/presentation/widgets/counter_action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

MerchantBranch _branch(int id, String name, {bool primary = false, String status = 'active'}) =>
    MerchantBranch.fromJson({
      'id': id,
      'merchant_id': 5,
      'name': name,
      'is_primary': primary,
      'locality': 'Kakkanad',
      'city': 'Kochi',
      'status': status,
    });

List<MerchantBranch> _branches = const [];

class _FakeBranchesController extends BusinessBranchesController {
  @override
  Future<List<MerchantBranch>> build() async => _branches;
}

/// Home with a button standing in for the docked Counter button, plus the
/// three places the sheet can send the merchant.
Widget _app() {
  final router = GoRouter(
    initialLocation: '/business',
    routes: [
      GoRoute(
        path: '/business',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => showCounterActionSheet(context), child: const Text('Counter')),
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: 'counter',
            builder: (context, state) => const Scaffold(body: Text('POS screen')),
          ),
          GoRoute(
            path: 'branches',
            builder: (context, state) => const Scaffold(body: Text('Branches screen')),
            routes: [
              GoRoute(
                path: ':id/qr',
                builder: (context, state) => Scaffold(body: Text('QR for branch ${state.pathParameters['id']}')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [businessBranchesControllerProvider.overrideWith(_FakeBranchesController.new)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Counter'));
  await tester.pumpAndSettle();
}

void main() {
  // A tap that misses must fail the test, never pass it vacuously.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('offers My QR and My POS; My POS opens Direct POS', (tester) async {
    _branches = [_branch(11, 'Main Branch', primary: true)];
    await _openSheet(tester);

    expect(find.text('My QR'), findsOneWidget);
    expect(find.text('My POS'), findsOneWidget);

    await tester.tap(find.text('My POS'));
    await tester.pumpAndSettle();

    expect(find.text('POS screen'), findsOneWidget);
    expect(find.text('My QR'), findsNothing);
  });

  testWidgets('My QR goes straight to the only active branch QR, ignoring inactive ones', (tester) async {
    _branches = [_branch(11, 'Main Branch', primary: true), _branch(12, 'Old Shop', status: 'inactive')];
    await _openSheet(tester);

    await tester.tap(find.text('My QR'));
    await tester.pumpAndSettle();

    expect(find.text('QR for branch 11'), findsOneWidget);
  });

  testWidgets('with several active branches, My QR asks which branch first', (tester) async {
    _branches = [_branch(11, 'Main Branch', primary: true), _branch(12, 'Edappally Branch')];
    await _openSheet(tester);

    await tester.tap(find.text('My QR'));
    await tester.pumpAndSettle();

    expect(find.text('Which branch?'), findsOneWidget);
    expect(find.text('Primary branch · Kakkanad · Kochi'), findsOneWidget);

    await tester.tap(find.text('Edappally Branch'));
    await tester.pumpAndSettle();

    expect(find.text('QR for branch 12'), findsOneWidget);
  });

  testWidgets('with no active branch, My QR sends the merchant to Branches and says why', (tester) async {
    _branches = [_branch(12, 'Old Shop', status: 'inactive')];
    await _openSheet(tester);

    await tester.tap(find.text('My QR'));
    await tester.pumpAndSettle();

    expect(find.text('Branches screen'), findsOneWidget);
    expect(find.text('Add an active branch to get your counter Purchase QR.'), findsOneWidget);
  });
}
