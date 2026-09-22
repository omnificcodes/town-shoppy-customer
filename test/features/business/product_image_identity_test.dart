import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/application/business_products_controller.dart';
import 'package:customer/features/business/data/business_products_repository.dart';
import 'package:customer/features/business/presentation/products/business_products_screen.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:customer/shared/widgets/multi_image_picker_field.dart';

/// Lists back whatever it is told to hold, so a test can add a product and
/// refresh the way the save flow does.
class _FakeRepository implements BusinessProductsRepository {
  List<Product> items = [];

  @override
  Future<OffsetPage<Product>> list({required int merchantId, int page = 1, int perPage = 20}) async =>
      OffsetPage(items: [...items], currentPage: 1, lastPage: 1, total: items.length);

  @override
  Future<Product> create({required int merchantId, required ProductInput input}) async => throw UnimplementedError();

  @override
  Future<Product> update(int id, ProductInput input) async => throw UnimplementedError();

  @override
  Future<void> delete(int id) async => throw UnimplementedError();
}

Product _product(int id, String name) => Product.fromJson({'id': id, 'name': name, 'price': 99, 'status': 'active'});

/// Holds the picker's URLs the way the product form does.
class _PickerHost extends StatefulWidget {
  const _PickerHost({required this.initial});

  final List<String> initial;

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  late List<String> _urls = List.of(widget.initial);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: MultiImagePickerField(
        urls: _urls,
        onChanged: (urls) => setState(() => _urls = urls),
        onUpload: (XFile file) async => throw UnimplementedError(),
      ),
    ),
  );
}

void main() {
  testWidgets('a new product at the top of the catalog does not hand its row to another product', (tester) async {
    final repository = _FakeRepository()..items = [_product(2, 'Egg Puffs'), _product(3, 'Chocolate Cake')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessProductsRepositoryProvider.overrideWithValue(repository),
          myMerchantIdProvider.overrideWithValue(3),
          isBusinessOwnerProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: BusinessProductsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The element that draws "Egg Puffs" today, at the top of the list.
    final before = tester.element(find.byKey(const ValueKey(2)));

    // A newly added product arrives first, pushing every other row down.
    repository.items = [_product(1, 'Sweet Box'), ...repository.items];
    final container = ProviderScope.containerOf(tester.element(find.byType(BusinessProductsScreen)));
    await container.read(businessProductsControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('Sweet Box'), findsOneWidget);

    // The invariant that matters for images: the row that was drawing Egg
    // Puffs must not have been updated in place into Sweet Box's row.
    // Unkeyed, that is exactly what happens -- the element survives, and
    // with it the Image that is still holding Egg Puffs' photo. Keyed,
    // Flutter cannot reuse it for a different product and builds a fresh
    // one. (The element does not follow Egg Puffs down either: a lazy
    // sliver matches children by index unless it is given a
    // findChildIndexCallback. That costs a rebuild, never a wrong photo.)
    expect(
      identical(tester.element(find.byKey(const ValueKey(1))), before),
      isFalse,
      reason: "Sweet Box must not inherit the element, and image, of the row Egg Puffs was using",
    );
  });

  testWidgets('removing one photo does not shuffle the others onto the wrong thumbnails', (tester) async {
    const a = 'https://cdn.test/a.jpg';
    const b = 'https://cdn.test/b.jpg';
    const c = 'https://cdn.test/c.jpg';

    await tester.pumpWidget(const _PickerHost(initial: [a, b, c]));
    await tester.pump();

    // The Image itself, not its wrapper -- both carry the URL as their key.
    Finder imageFor(String url) => find.byWidgetPredicate((w) => w is Image && w.key == ValueKey(url));

    final beforeB = tester.element(imageFor(b));
    expect(imageFor(a), findsOneWidget);

    // Remove the first photo: b and c each shift down one place.
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump();

    expect(imageFor(a), findsNothing);
    expect(
      identical(tester.element(imageFor(b)), beforeB),
      isTrue,
      reason: 'the second photo keeps its own thumbnail rather than inheriting the removed one',
    );
  });
}
