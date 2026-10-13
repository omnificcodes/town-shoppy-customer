import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/presentation/business_routes.dart';
import 'package:customer/features/business/presentation/stamp_cards/stamp_card_form_screen.dart';
import 'package:customer/features/business/presentation/stamp_cards/stamp_card_picker.dart';
import 'package:customer/features/home/presentation/widgets/stamp_cards_section.dart';
import 'package:customer/features/stamp_cards/application/stamp_cards_providers.dart';
import 'package:customer/features/stamp_cards/data/models/stamp_card.dart';
import 'package:customer/features/stamp_cards/data/stamp_cards_repository.dart';
import 'package:customer/features/stamp_cards/presentation/stamp_card_face.dart';
import 'package:customer/features/stamp_cards/presentation/stamp_cards_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CustomerStampCard _card({int id = 1, int count = 2, int required = 5, String status = 'collecting'}) => CustomerStampCard.fromJson({
  'id': id,
  'stamp_card_id': 7,
  'title': 'Coffee lovers',
  'icon': 'coffee',
  'merchant': {'id': 3, 'name': 'Kairaly Bakers'},
  'stamps_required': required,
  'stamps_count': count,
  'reward_text': 'Free coffee',
  'status': status,
});

StampCardProgramme _programme({int id = 7, String status = 'active', double? minBill}) => StampCardProgramme.fromJson({
  'id': id,
  'merchant_id': 3,
  'title': 'Coffee lovers',
  'stamps_required': 5,
  'reward_text': 'Free coffee',
  'min_bill_amount': minBill,
  'icon': 'coffee',
  'status': status,
});

class _FakeRepository extends StampCardsRepository {
  _FakeRepository() : super(Dio());

  StampCardInput? created;

  @override
  Future<StampCardProgramme> createProgramme(int merchantId, StampCardInput input) async {
    created = input;
    return StampCardProgramme.fromJson({...input.toJson(), 'id': 9, 'merchant_id': merchantId});
  }
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  group('the customer\'s cards', () {
    testWidgets('the card face shows the shop, the reward and one slot per stamp with the collected ones filled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StampCardFace(title: 'Coffee lovers', rewardText: 'Free coffee', stampsRequired: 5, stampsCount: 2, icon: 'coffee', merchantName: 'Kairaly Bakers'),
          ),
        ),
      );
      expect(find.text('KAIRALY BAKERS'), findsOneWidget);
      expect(find.text('Free coffee'), findsOneWidget);
      expect(find.text('2 of 5 stamps · 3 to go'), findsOneWidget);
      expect(find.text('☕'), findsNWidgets(2));
    });

    testWidgets('the list shows live cards as cards and claimed rewards underneath', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myStampCardsProvider.overrideWith((ref) async => [_card(id: 1, count: 5, status: 'full'), _card(id: 2), _card(id: 3, count: 5, status: 'rewarded')]),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const StampCardsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Card full — show it at the shop!'), findsOneWidget);
      expect(find.text('2 of 5 stamps · 3 to go'), findsOneWidget);
      expect(find.text('REWARDS CLAIMED'), findsOneWidget);
      expect(find.text('Coffee lovers · Kairaly Bakers'), findsOneWidget);
    });

    testWidgets('Home shows the strip only while a card is being collected', (tester) async {
      Widget home(List<CustomerStampCard> cards) => ProviderScope(
        overrides: [myStampCardsProvider.overrideWith((ref) async => cards)],
        child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SingleChildScrollView(child: StampCardsSection()))),
      );

      await tester.pumpWidget(home([_card(status: 'rewarded', count: 5)]));
      await tester.pumpAndSettle();
      expect(find.text('My stamp cards'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(home([_card()]));
      await tester.pumpAndSettle();
      expect(find.text('My stamp cards'), findsOneWidget);
      expect(find.text('Coffee lovers'), findsOneWidget);
    });
  });

  group('the shop', () {
    testWidgets('the picker greys out a card the bill cannot stamp, and offers no stamp', (tester) async {
      ({int? programmeId})? choice;
      final programmes = StampCardProgrammes(
        enabled: true,
        limit: 2,
        activeCount: 2,
        items: [_programme(id: 7), _programme(id: 8, minBill: 500), _programme(id: 9, status: 'inactive')],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => choice = await showStampCardPicker(
                  context,
                  programmes,
                  progress: [_card(count: 3)],
                  billAmount: 200,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 5 stamps so far'), findsOneWidget);
      expect(find.text('Needs a bill of ₹500.00 or more'), findsOneWidget);
      expect(find.text('Coffee lovers'), findsNWidgets(2)); // the inactive one is left out

      await tester.tap(find.text('3 of 5 stamps so far'));
      await tester.pumpAndSettle();
      expect(choice?.programmeId, 7);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No stamp this time'));
      await tester.pumpAndSettle();
      expect(choice, isNotNull);
      expect(choice?.programmeId, isNull);
    });

    testWidgets('the form needs a name and a reward, and sends the stamp count from the stepper', (tester) async {
      final repository = _FakeRepository();
      tester.view.physicalSize = const Size(420, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stampCardsRepositoryProvider.overrideWithValue(repository),
            myMerchantIdProvider.overrideWithValue(3),
            myMerchantProvider.overrideWith((ref) async => BusinessMerchant.fromJson({'id': 3, 'name': 'Kairaly Bakers', 'status': 'active'})),
            stampCardProgrammesProvider.overrideWith((ref) async => const StampCardProgrammes(items: [], enabled: true, limit: 2, activeCount: 0)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: BusinessRoutes.stampCardNew,
              routes: [
                GoRoute(path: BusinessRoutes.stampCards, builder: (context, state) => const Scaffold(body: Text('Cards'))),
                GoRoute(path: BusinessRoutes.stampCardNew, builder: (context, state) => const StampCardFormScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create card'));
      await tester.pumpAndSettle();
      expect(find.text('Give the card a name, e.g. "Coffee lovers".'), findsOneWidget);
      expect(repository.created, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Card name'), 'Coffee lovers');
      await tester.enterText(find.widgetWithText(TextField, 'Reward when the card is full'), 'Free coffee');
      await tester.tap(find.byTooltip('More stamps'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More stamps'));
      await tester.pumpAndSettle();
      expect(find.text('7 stamps'), findsOneWidget);

      await tester.tap(find.text('Create card'));
      await tester.pumpAndSettle();
      expect(repository.created?.stampsRequired, 7);
      expect(repository.created?.rewardText, 'Free coffee');
      expect(repository.created?.minBillAmount, isNull);
      expect(find.text('Cards'), findsOneWidget);
    });
  });
}
