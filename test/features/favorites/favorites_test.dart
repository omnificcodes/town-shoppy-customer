import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/favorites/application/favorites_controller.dart';
import 'package:customer/features/favorites/data/favorites_repository.dart';
import 'package:customer/features/favorites/presentation/favorites_screen.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/presentation/favorite_button.dart';

import '../../helpers/fake_favorites_repository.dart';

Merchant _merchant(int id, String name) => Merchant(
  id: id,
  name: name,
  description: null,
  logoUrl: null,
  websiteUrl: null,
  contactMobileNumber: null,
  socialLinks: null,
  discountRate: null,
  acceptsTownCoin: false,
  category: null,
  association: null,
  branch: null,
);

ProviderContainer _container(FakeFavoritesRepository repository) {
  final container = ProviderContainer(overrides: [favoritesRepositoryProvider.overrideWithValue(repository)]);
  addTearDown(container.dispose);
  return container;
}

Widget _app(FakeFavoritesRepository repository, Widget home) => ProviderScope(
  overrides: [favoritesRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(theme: AppTheme.light, home: home),
);

void main() {
  group('FavoriteMerchantIdsController', () {
    test('loads the saved ids', () async {
      final container = _container(FakeFavoritesRepository(saved: {4, 9}));

      expect(await container.read(favoriteMerchantIdsProvider.future), {4, 9});
      expect(container.read(isFavoriteMerchantProvider(4)), isTrue);
      expect(container.read(isFavoriteMerchantProvider(5)), isFalse);
    });

    test('toggle saves, then removes, and persists both through the repository', () async {
      final repository = FakeFavoritesRepository();
      final container = _container(repository);
      await container.read(favoriteMerchantIdsProvider.future);
      final controller = container.read(favoriteMerchantIdsProvider.notifier);

      expect(await controller.toggle(7), isTrue);
      expect(container.read(isFavoriteMerchantProvider(7)), isTrue);
      expect(repository.saved, {7});

      expect(await controller.toggle(7), isFalse);
      expect(container.read(isFavoriteMerchantProvider(7)), isFalse);
      expect(repository.saved, isEmpty);
    });

    test('rolls the heart back when the server refuses', () async {
      final container = _container(FakeFavoritesRepository(saved: {3}, failWrites: true));
      await container.read(favoriteMerchantIdsProvider.future);
      final controller = container.read(favoriteMerchantIdsProvider.notifier);

      await expectLater(controller.toggle(8), throwsStateError);
      expect(container.read(isFavoriteMerchantProvider(8)), isFalse);

      await expectLater(controller.toggle(3), throwsStateError);
      expect(container.read(isFavoriteMerchantProvider(3)), isTrue);
    });
  });

  group('FavoriteButton', () {
    testWidgets('fills on tap, names the shop for screen readers, and empties on a second tap', (tester) async {
      final repository = FakeFavoritesRepository();
      await tester.pumpWidget(
        _app(repository, const Scaffold(body: FavoriteButton(merchantId: 1, merchantName: 'Corner Cafe'))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byTooltip('Save Corner Cafe to favorites'), findsOneWidget);

      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byTooltip('Remove Corner Cafe from favorites'), findsOneWidget);
      expect(find.text('Saved to favorites'), findsOneWidget);
      expect(repository.saved, {1});

      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(repository.saved, isEmpty);
    });

    testWidgets('keeps a 48dp touch target', (tester) async {
      await tester.pumpWidget(
        _app(
          FakeFavoritesRepository(),
          const Scaffold(body: Center(child: FavoriteButton(merchantId: 1, merchantName: 'Corner Cafe'))),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(FavoriteButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('FavoritesScreen', () {
    testWidgets('shows a friendly empty state when nothing is saved', (tester) async {
      await tester.pumpWidget(_app(FakeFavoritesRepository(), const FavoritesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No favorites yet'), findsOneWidget);
      expect(find.text('Discover shops'), findsOneWidget);
    });

    testWidgets('lists saved shops and drops one the moment its heart is tapped', (tester) async {
      final repository = FakeFavoritesRepository(
        saved: {1, 2},
        merchants: [_merchant(1, 'Corner Cafe'), _merchant(2, 'Book Nook')],
      );
      await tester.pumpWidget(_app(repository, const FavoritesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.text('Book Nook'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Corner Cafe from favorites'));
      await tester.pumpAndSettle();

      expect(find.text('Corner Cafe'), findsNothing);
      expect(find.text('Book Nook'), findsOneWidget);
      expect(repository.saved, {2});
    });
  });
}
