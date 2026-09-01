import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/purchases/data/customer_qr_repository.dart';
import 'package:customer/features/purchases/presentation/my_qr_screen.dart';

class _FakeCustomerQrRepository implements CustomerQrRepository {
  static const _showToken = 'tok_show';
  static const _regenerateToken = 'tok_regenerated';

  @override
  Future<String> show() async => _showToken;

  @override
  Future<String> regenerate() async => _regenerateToken;
}

class _FailingCustomerQrRepository implements CustomerQrRepository {
  @override
  Future<String> show() async => throw Exception('boom');

  @override
  Future<String> regenerate() async => throw Exception('boom');
}

Widget _wrap({CustomerQrRepository? repository}) {
  return ProviderScope(
    overrides: [if (repository != null) customerQrRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.light, home: const MyQrScreen()),
  );
}

void main() {
  group('MyQrScreen', () {
    testWidgets('renders the token as a QR code with a regenerate button', (tester) async {
      await tester.pumpWidget(_wrap(repository: _FakeCustomerQrRepository()));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Regenerate code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping regenerate re-fetches a fresh QR without error', (tester) async {
      final fake = _FakeCustomerQrRepository();
      await tester.pumpWidget(_wrap(repository: fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Regenerate code'));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed initial load shows the error state with a retry action', (tester) async {
      final fake = _FailingCustomerQrRepository();
      await tester.pumpWidget(_wrap(repository: fake));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
