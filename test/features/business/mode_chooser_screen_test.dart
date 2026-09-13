import 'package:customer/core/app_mode/app_mode.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/presentation/mode_chooser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/responsive_test_helper.dart';

const _account = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['customer', 'merchant_owner'],
  customerProfile: null,
  merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

class _MemoryStorage implements SecureStorageService {
  final Map<String, String> store = {};
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> delete(String key) async => store.remove(key);
}

void main() {
  late _MemoryStorage storage;
  late List<String> visited;

  Widget wrap() {
    storage = _MemoryStorage();
    visited = [];
    final router = GoRouter(
      initialLocation: '/choose-mode',
      routes: [
        GoRoute(path: '/choose-mode', builder: (_, _) => const ModeChooserScreen()),
        GoRoute(path: '/home', builder: (_, _) => const Text('customer-home')),
        GoRoute(path: '/business', builder: (_, _) => const Text('business-home')),
      ],
      redirect: (_, state) {
        visited.add(state.matchedLocation);
        return null;
      },
    );
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        secureStorageServiceProvider.overrideWithValue(storage),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  testWidgets('renders both options without overflow at every viewport', (tester) async {
    await forEachViewport(
      tester,
      wrap,
      verify: (tester, size) async {
        expect(find.text('Customer app'), findsOneWidget);
        expect(find.text('Business app'), findsOneWidget);
        expect(find.textContaining('+919990003001'), findsOneWidget);
      },
    );
  });

  testWidgets('choosing Business persists the mode and lands on the business root', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('choose-business')));
    await tester.pumpAndSettle();

    expect(storage.store['app_mode'], AppMode.business.name);
    expect(find.text('business-home'), findsOneWidget);
    expect(visited.last, '/business');
  });

  testWidgets('choosing Customer persists the mode and lands on Home', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('choose-customer')));
    await tester.pumpAndSettle();

    expect(storage.store['app_mode'], AppMode.customer.name);
    expect(find.text('customer-home'), findsOneWidget);
  });
}
