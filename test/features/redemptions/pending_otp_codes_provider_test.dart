import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/redemptions/application/pending_otp_codes_provider.dart';

void main() {
  group('PendingOtpCodes', () {
    test('consume returns a stashed code exactly once, then null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(pendingOtpCodesProvider.notifier).stash(8, '585937');

      expect(container.read(pendingOtpCodesProvider.notifier).consume(8), '585937');
      expect(container.read(pendingOtpCodesProvider.notifier).consume(8), isNull);
    });

    test('consume for a redemption id that was never stashed returns null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingOtpCodesProvider.notifier).consume(999), isNull);
    });

    test('stashing for one redemption does not affect another', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingOtpCodesProvider.notifier);

      notifier.stash(1, '111111');
      notifier.stash(2, '222222');

      expect(notifier.consume(1), '111111');
      expect(notifier.consume(2), '222222');
    });
  });
}
