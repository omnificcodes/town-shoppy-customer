import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/business_merchant_repository.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/presentation/edit_business_profile_screen.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/merchants/presentation/merchant_logo.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _account = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['merchant_owner'],
  customerProfile: null,
  merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

BusinessMerchant _merchant() => BusinessMerchant.fromJson({
  'id': 5,
  'name': 'Kairaly Bakers',
  'owner_name': 'Asha',
  'status': 'active',
  'accepts_town_coin': true,
  // Mandatory for every business -- a merchant without a rate cannot save.
  'discount_rate': 10,
  'logo_url': 'https://api.townshoppy.com/storage/uploads/images/logo.png',
  'cover_image_url': 'https://api.townshoppy.com/storage/uploads/images/cover.png',
  // Saved from the web edit sheet: free-typed platform names.
  'social_links': {'Instagram': 'https://instagram.com/kairaly', 'twitter': 'https://x.com/kairaly'},
});

/// Records the PATCH body instead of sending it.
class _FakeMerchantRepository extends BusinessMerchantRepository {
  _FakeMerchantRepository() : super(Dio());

  Map<String, dynamic>? sent;

  @override
  Future<BusinessMerchant> update(int merchantId, Map<String, dynamic> fields) async {
    sent = fields;
    return _merchant();
  }
}

Widget _wrap(_FakeMerchantRepository repository) {
  final router = GoRouter(
    initialLocation: '/business/profile/edit',
    routes: [
      GoRoute(
        path: '/business/profile',
        builder: (context, state) => const Scaffold(body: Text('Business profile')),
        routes: [GoRoute(path: 'edit', builder: (context, state) => const EditBusinessProfileScreen())],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      myMerchantProvider.overrideWith((ref) async => _merchant()),
      merchantCategoriesProvider.overrideWith((ref) async => const <MerchantCategory>[]),
      businessMerchantRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Finder _field(String label) => find.widgetWithText(TextField, label);

/// Scrolls until [finder] is built, then brings it fully on screen --
/// `scrollUntilVisible` alone can stop with the target just past the edge,
/// where a tap would miss.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  // A tap that misses must fail the test, never pass it vacuously.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('shows one field per platform, with a web-saved "Instagram" link in the Instagram field', (tester) async {
    await tester.pumpWidget(_wrap(_FakeMerchantRepository()));
    await tester.pumpAndSettle();

    // The list builds lazily, so bring each field on screen before checking it.
    for (final label in ['YouTube', 'Facebook', 'Instagram', 'LinkedIn']) {
      await _scrollTo(tester, _field(label));
      expect(_field(label), findsOneWidget);
      if (label == 'Instagram') expect(find.text('https://instagram.com/kairaly'), findsOneWidget);
    }
    expect(find.text('Add social link'), findsNothing);
  });

  testWidgets('a link for the wrong site blocks Save', (tester) async {
    final repository = _FakeMerchantRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _scrollTo(tester, _field('YouTube'));
    await tester.enterText(_field('YouTube'), 'https://vimeo.com/kairaly');
    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.sent, isNull);
    await tester.scrollUntilVisible(find.text('Enter a YouTube link'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Enter a YouTube link'), findsOneWidget);
  });

  testWidgets('Save sends the platform links under lowercase keys, keeps other platforms, logo and cover', (
    tester,
  ) async {
    final repository = _FakeMerchantRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _scrollTo(tester, _field('LinkedIn'));
    await tester.enterText(_field('LinkedIn'), ' https://www.linkedin.com/company/kairaly ');
    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final sent = repository.sent!;
    expect(sent['social_links'], {
      'twitter': 'https://x.com/kairaly',
      'instagram': 'https://instagram.com/kairaly',
      'linkedin': 'https://www.linkedin.com/company/kairaly',
    });
    expect(sent['logo_url'], 'https://api.townshoppy.com/storage/uploads/images/logo.png');
    expect(sent['cover_image_url'], 'https://api.townshoppy.com/storage/uploads/images/cover.png');
    // Mandatory for every business: the rate goes with every save, and
    // Town Coin acceptance is always sent as on -- there is no switch.
    expect(sent['discount_rate'], 10);
    expect(sent['accepts_town_coin'], isTrue);
    expect(find.text('Business profile'), findsOneWidget);
  });

  testWidgets('the discount rate is required: clearing it blocks Save, and Town Coin has no off switch', (
    tester,
  ) async {
    final repository = _FakeMerchantRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _scrollTo(tester, _field('Discount rate (%) *'));
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.textContaining('Accepts Town Coin: on'), findsOneWidget);

    await tester.enterText(_field('Discount rate (%) *'), '');
    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.sent, isNull);
    await tester.scrollUntilVisible(find.text('Discount rate is required.'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Discount rate is required.'), findsOneWidget);
  });

  testWidgets('merchant logos fall back to an HTML image on web so uploads show without CORS headers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MerchantLogo(url: 'https://api.townshoppy.com/storage/uploads/images/logo.png', merchantName: 'Kairaly'),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).webHtmlElementStrategy, WebHtmlElementStrategy.fallback);
  });

  testWidgets('a business that never set its hours starts open 9 to 6 every day, with Apply to all days on', (tester) async {
    final repository = _FakeMerchantRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Apply to all days'));
    final applyAll = find.ancestor(of: find.text('Apply to all days'), matching: find.byType(Row)).first;
    expect(tester.widget<Switch>(find.descendant(of: applyAll, matching: find.byType(Switch))).value, isTrue);

    await _scrollTo(tester, find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final hours = repository.sent?['business_hours'] as Map<String, dynamic>;
    expect(hours.keys, hasLength(7));
    for (final day in hours.values) {
      expect(day, {'open': '09:00', 'close': '18:00', 'closed': false});
    }
  });
}
