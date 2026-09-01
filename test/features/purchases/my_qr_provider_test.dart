import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/purchases/application/my_qr_provider.dart';
import 'package:customer/features/purchases/data/customer_qr_repository.dart';

class FakeCustomerQrRepository implements CustomerQrRepository {
  FakeCustomerQrRepository({this.showToken = 'tok_show', this.regenerateToken = 'tok_regenerated', this.showError});

  String showToken;
  String regenerateToken;
  Object? showError;
  int showCallCount = 0;
  int regenerateCallCount = 0;

  @override
  Future<String> show() async {
    showCallCount++;
    if (showError != null) throw showError!;
    return showToken;
  }

  @override
  Future<String> regenerate() async {
    regenerateCallCount++;
    return regenerateToken;
  }
}

void main() {
  group('MyQrController', () {
    test('build() lazily loads the token from the repository', () async {
      final fake = FakeCustomerQrRepository();
      final container = ProviderContainer(overrides: [customerQrRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final token = await container.read(myQrProvider.future);

      expect(token, 'tok_show');
      expect(fake.showCallCount, 1);
    });

    test('a repeat read does not re-fetch (same token, cached)', () async {
      final fake = FakeCustomerQrRepository();
      final container = ProviderContainer(overrides: [customerQrRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(myQrProvider.future);
      final second = await container.read(myQrProvider.future);

      expect(second, 'tok_show');
      expect(fake.showCallCount, 1);
    });

    test('regenerate() replaces the held token with a fresh one', () async {
      final fake = FakeCustomerQrRepository();
      final container = ProviderContainer(overrides: [customerQrRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      await container.read(myQrProvider.future);

      await container.read(myQrProvider.notifier).regenerate();

      expect(fake.regenerateCallCount, 1);
      final state = container.read(myQrProvider);
      expect(state.value, 'tok_regenerated');
    });

    test('a failed initial load surfaces as an AsyncError', () async {
      final fake = FakeCustomerQrRepository(showError: Exception('boom'));
      final container = ProviderContainer(overrides: [customerQrRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      var state = container.read(myQrProvider);
      for (var i = 0; i < 50 && !state.hasError; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        state = container.read(myQrProvider);
      }

      expect(state.hasError, isTrue);
    });
  });
}
