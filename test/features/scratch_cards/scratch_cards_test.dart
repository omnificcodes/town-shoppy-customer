import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/presentation/business_routes.dart';
import 'package:customer/features/business/presentation/scratch_cards/scratch_card_form_screen.dart';
import 'package:customer/features/business/presentation/scratch_cards/scratch_card_picker.dart';
import 'package:customer/features/home/presentation/widgets/scratch_cards_banner.dart';
import 'package:customer/features/scratch_cards/application/scratch_cards_providers.dart';
import 'package:customer/features/scratch_cards/data/models/scratch_card.dart';
import 'package:customer/features/scratch_cards/data/scratch_cards_repository.dart';
import 'package:customer/features/scratch_cards/presentation/scratch_cards_screen.dart';
import 'package:customer/features/scratch_cards/presentation/scratch_foil.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CustomerScratchCard _card({int id = 1, String status = 'unscratched', Map<String, dynamic>? reward}) =>
    CustomerScratchCard.fromJson({
      'id': id,
      'title': 'Festive surprise',
      'theme': 'festive',
      'status': status,
      'merchant': {'id': 3, 'name': 'Kairaly Bakers'},
      'reward': reward,
      'expires_at': '2026-11-07T00:00:00+05:30',
      'created_at': '2026-10-08T10:00:00+05:30',
    });

class _FakeRepository extends ScratchCardsRepository {
  _FakeRepository() : super(Dio());

  ScratchCardDesignInput? created;

  @override
  Future<ScratchCardDesign> createDesign(int merchantId, ScratchCardDesignInput input) async {
    created = input;
    return ScratchCardDesign.fromJson({...input.toJson(), 'id': 9, 'merchant_id': merchantId});
  }
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  group('the customer\'s cards', () {
    testWidgets('the list shows cards to scratch first, then scratched ones with their code', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myScratchCardsProvider.overrideWith(
              (ref) async => [
                _card(id: 1),
                _card(id: 2, status: 'scratched', reward: {'type': 'offer', 'offer_text': '20% off', 'code': 'ABCDEFGH'}),
                _card(id: 3, status: 'redeemed', reward: {'type': 'coins', 'coin_amount': 50, 'code': 'QWERTYUP'}),
              ],
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const ScratchCardsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SCRATCH NOW'), findsOneWidget);
      expect(find.text('Scratch'), findsOneWidget);
      expect(find.text('SCRATCHED'), findsOneWidget);
      expect(find.textContaining('ABCD-EFGH'), findsOneWidget);
      expect(find.text('Show at shop'), findsOneWidget);
      expect(find.text('Used'), findsOneWidget);
    });

    testWidgets('Home shows a banner only while a card is waiting', (tester) async {
      Widget home(List<CustomerScratchCard> cards) => ProviderScope(
        overrides: [myScratchCardsProvider.overrideWith((ref) async => cards)],
        child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: ScratchCardsBanner())),
      );

      await tester.pumpWidget(home([_card(status: 'scratched', reward: {'type': 'coins', 'coin_amount': 10})]));
      await tester.pumpAndSettle();
      expect(find.textContaining('waiting'), findsNothing);

      // A fresh ProviderScope, so the new override takes effect.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(home([_card(), _card(id: 2)]));
      await tester.pumpAndSettle();
      expect(find.text('2 scratch cards are waiting!'), findsOneWidget);
    });

    testWidgets('the foil asks the server to scratch on the first stroke and reports how much is cleared', (tester) async {
      var firstTouches = 0;
      double progress = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: ScratchFoil(enabled: true, onFirstTouch: () => firstTouches++, onProgress: (p) => progress = p),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(ScratchFoil)) - const Offset(120, 0));
      for (var i = 0; i < 24; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await gesture.down(tester.getCenter(find.byType(ScratchFoil)) + const Offset(0, 60));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.up();

      expect(firstTouches, 1);
      expect(progress, greaterThan(0.1));
      expect(progress, lessThan(1));
    });
  });

  group('the shop', () {
    testWidgets('the picker offers active designs and a way to give none', (tester) async {
      ({int? designId})? choice;
      final designs = ScratchCardDesigns(
        enabled: true,
        remaining: 4,
        items: [
          ScratchCardDesign.fromJson({'id': 1, 'merchant_id': 3, 'title': 'Festive', 'reward_type': 'offer', 'offer_text': '20% off', 'validity_days': 30, 'theme': 'festive', 'status': 'active'}),
          ScratchCardDesign.fromJson({'id': 2, 'merchant_id': 3, 'title': 'Old one', 'reward_type': 'coins', 'coin_amount': 5, 'validity_days': 30, 'theme': 'gold', 'status': 'inactive'}),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => choice = await showScratchCardPicker(context, designs),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('4 left this month on your plan.'), findsOneWidget);
      expect(find.text('Festive'), findsOneWidget);
      expect(find.text('Old one'), findsNothing);

      await tester.tap(find.text('Festive'));
      await tester.pumpAndSettle();
      expect(choice?.designId, 1);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No card this time'));
      await tester.pumpAndSettle();
      expect(choice, isNotNull);
      expect(choice?.designId, isNull);
    });

    testWidgets('the design form needs the reward for the chosen type and sends what was typed', (tester) async {
      final repository = _FakeRepository();
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scratchCardsRepositoryProvider.overrideWithValue(repository),
            myMerchantIdProvider.overrideWithValue(3),
            scratchCardDesignsProvider.overrideWith((ref) async => const ScratchCardDesigns(items: [], enabled: true, remaining: 10)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: BusinessRoutes.scratchCardNew,
              routes: [
                GoRoute(path: BusinessRoutes.scratchCards, builder: (context, state) => const Scaffold(body: Text('Designs'))),
                GoRoute(path: BusinessRoutes.scratchCardNew, builder: (context, state) => const ScratchCardFormScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Festive surprise');
      await tester.tap(find.text('Add design'));
      await tester.pumpAndSettle();
      expect(find.text('Write the offer the customer wins.'), findsOneWidget);
      expect(repository.created, isNull);

      await tester.tap(find.text('Town Coins').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Town Coins'), '50');
      await tester.tap(find.text('Add design'));
      await tester.pumpAndSettle();

      expect(repository.created?.rewardType, 'coins');
      expect(repository.created?.coinAmount, 50);
      expect(repository.created?.validityDays, 30);
      expect(find.text('Designs'), findsOneWidget);
    });
  });
}
