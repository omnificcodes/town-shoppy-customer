import 'package:customer/core/app_mode/app_mode.dart';
import 'package:customer/core/app_mode/app_mode_controller.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage implements SecureStorageService {
  _FakeStorage([Map<String, String>? seed]) : _store = {...?seed};

  final Map<String, String> _store;

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);
}

void main() {
  ProviderContainer build(_FakeStorage storage) {
    final container = ProviderContainer(overrides: [secureStorageServiceProvider.overrideWithValue(storage)]);
    addTearDown(container.dispose);
    return container;
  }

  test('starts unloaded, then restores the saved mode from storage', () async {
    final container = build(_FakeStorage({AppConstants.secureStorageAppModeKey: 'business'}));

    expect(container.read(appModeControllerProvider).loaded, isFalse);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(appModeControllerProvider);
    expect(state.loaded, isTrue);
    expect(state.mode, AppMode.business);
  });

  test('a missing or unknown saved value loads as "no choice yet"', () async {
    final container = build(_FakeStorage({AppConstants.secureStorageAppModeKey: 'garbage'}));
    container.read(appModeControllerProvider); // instantiate so the restore starts
    await Future<void>.delayed(Duration.zero);

    final state = container.read(appModeControllerProvider);
    expect(state.loaded, isTrue);
    expect(state.mode, isNull);
  });

  test('select persists and clear forgets', () async {
    final storage = _FakeStorage();
    final container = build(storage);

    // Deliberately no settle before select(): a choice made while the
    // disk read is still in flight must not be clobbered by it.
    await container.read(appModeControllerProvider.notifier).select(AppMode.customer);
    await Future<void>.delayed(Duration.zero);
    expect(await storage.read(AppConstants.secureStorageAppModeKey), 'customer');
    expect(container.read(appModeControllerProvider).mode, AppMode.customer);

    await container.read(appModeControllerProvider.notifier).clear();
    expect(await storage.read(AppConstants.secureStorageAppModeKey), isNull);
    expect(container.read(appModeControllerProvider).mode, isNull);
    expect(container.read(appModeControllerProvider).loaded, isTrue);
  });
}
