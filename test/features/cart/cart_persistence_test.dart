import 'dart:convert';

import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/features/cart/application/cart_controller.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bag survives a restart: it is written to the device store on every
/// change and read back when the controller is first built.
class _MemoryStorage extends SecureStorageService {
  _MemoryStorage() : super(const FlutterSecureStorage());

  final values = <String, String>{};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}

Product _product({int id = 1, String name = 'Butter Cookies', double price = 149}) => Product.fromJson({
  'id': id,
  'merchant': {'id': 3, 'name': 'Kairaly Bakers', 'contact_mobile_number': '9876543210'},
  'name': name,
  'price': price,
  'mrp': 200,
  'status': 'active',
});

ProviderContainer _container(_MemoryStorage storage) {
  return ProviderContainer(overrides: [secureStorageServiceProvider.overrideWithValue(storage)]);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('every change is written to the store, and emptying the bag removes it', () async {
    final storage = _MemoryStorage();
    final container = _container(storage);
    addTearDown(container.dispose);

    final controller = container.read(cartControllerProvider.notifier);
    controller.add(_product());
    controller.setQuantity(_product(), 3);
    await _settle();

    final stored = jsonDecode(storage.values[CartController.storageKey]!) as Map<String, dynamic>;
    expect((stored['lines'] as List).single['quantity'], 3);
    expect((stored['lines'] as List).single['product']['name'], 'Butter Cookies');

    controller.clear();
    await _settle();
    expect(storage.values.containsKey(CartController.storageKey), isFalse);
  });

  test('a stored bag comes back on the next launch, with its shop, prices and quantities', () async {
    final storage = _MemoryStorage();
    final first = _container(storage);
    first.read(cartControllerProvider.notifier)
      ..add(_product())
      ..add(_product(id: 2, name: 'Banana Chips', price: 120));
    await _settle();
    first.dispose();

    final second = _container(storage);
    addTearDown(second.dispose);
    expect(second.read(cartControllerProvider).isEmpty, isTrue, reason: 'the read is asynchronous');
    await _settle();

    final cart = second.read(cartControllerProvider);
    expect(cart.lines, hasLength(2));
    expect(cart.merchantName, 'Kairaly Bakers');
    expect(cart.total, 269);
    expect(cart.quantityOf(2), 1);
    expect(cart.contactMobileNumber, '9876543210');
  });

  test('what was added while the store was being read is kept over the stored bag', () async {
    final storage = _MemoryStorage();
    storage.values[CartController.storageKey] = jsonEncode(
      CartState(lines: [CartLine(product: _product(id: 9, name: 'Stored'), quantity: 1)]).toJson(),
    );
    final container = _container(storage);
    addTearDown(container.dispose);

    container.read(cartControllerProvider.notifier).add(_product(id: 1, name: 'Fresh'));
    await _settle();

    expect(container.read(cartControllerProvider).lines.single.product.name, 'Fresh');
  });

  test('a corrupt stored bag is treated as an empty one', () async {
    final storage = _MemoryStorage();
    storage.values[CartController.storageKey] = 'not json';
    final container = _container(storage);
    addTearDown(container.dispose);

    container.read(cartControllerProvider);
    await _settle();

    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('Product round-trips through toJson/fromJson', () {
    final product = _product();
    final copy = Product.fromJson(product.toJson());

    expect(copy.id, product.id);
    expect(copy.merchantId, product.merchantId);
    expect(copy.merchantContactMobileNumber, product.merchantContactMobileNumber);
    expect(copy.price, product.price);
    expect(copy.saving, product.saving);
  });
}
