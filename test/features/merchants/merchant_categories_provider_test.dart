import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/merchants/data/merchant_categories_repository.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';

class FakeMerchantCategoriesRepository implements MerchantCategoriesRepository {
  FakeMerchantCategoriesRepository({this.categories, this.error});

  final List<MerchantCategory>? categories;
  final AppException? error;

  @override
  Future<List<MerchantCategory>> list() async {
    if (error != null) throw error!;
    return categories!;
  }
}

void main() {
  test('merchantCategoriesProvider surfaces the loaded categories', () async {
    const categories = [MerchantCategory(id: 1, name: 'Bakery', slug: 'bakery')];
    final container = ProviderContainer(
      overrides: [merchantCategoriesRepositoryProvider.overrideWithValue(FakeMerchantCategoriesRepository(categories: categories))],
    );
    addTearDown(container.dispose);

    final result = await container.read(merchantCategoriesProvider.future);

    expect(result, hasLength(1));
    expect(result.first.name, 'Bakery');
  });

  test('merchantCategoriesProvider surfaces a backend error', () async {
    final container = ProviderContainer(
      overrides: [
        merchantCategoriesRepositoryProvider.overrideWithValue(FakeMerchantCategoriesRepository(error: const ServerException())),
      ],
    );
    addTearDown(container.dispose);

    var state = container.read(merchantCategoriesProvider);
    for (var i = 0; i < 50 && !state.hasError; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = container.read(merchantCategoriesProvider);
    }

    expect(state.hasError, isTrue);
    expect(state.error, isA<ServerException>());
  });
}
