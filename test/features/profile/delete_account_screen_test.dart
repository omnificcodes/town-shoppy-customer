import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/profile/presentation/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_test_helper.dart';

Account _account({bool hasPassword = true, bool canDeleteAccount = true}) => Account(
      id: 1,
      mobileNumber: '+919990003001',
      status: 'active',
      isSuperAdmin: false,
      roles: const ['customer'],
      hasPassword: hasPassword,
      canDeleteAccount: canDeleteAccount,
      customerProfile: CustomerProfile(
        id: 7,
        name: 'Ammu Krishnan',
        dateOfBirth: null,
        anniversaryDate: null,
        socialLinks: const {},
        referralCode: 'AMMU01',
        status: 'active',
        profilePhotoUrl: null,
        coverImageUrl: null,
      ),
    );

/// Stands in for the real controller: records what the screen asks for,
/// and either signs out (as a real deletion does) or throws [failure].
class _FakeAuthController extends AuthController {
  _FakeAuthController(this.account, {this.failure});

  final Account account;
  final AppException? failure;
  final passwords = <String?>[];

  @override
  AuthState build() => AuthAuthenticated(account);

  @override
  Future<void> deleteAccount({String? password}) async {
    passwords.add(password);
    final failure = this.failure;
    if (failure != null) throw failure;
    state = const AuthUnauthenticated();
  }
}

Widget _wrap(_FakeAuthController controller) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(theme: AppTheme.light, home: const DeleteAccountScreen()),
  );
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

bool _deleteEnabled(WidgetTester tester) {
  final button = find.ancestor(of: find.text('Delete my account'), matching: find.bySubtype<ButtonStyleButton>());
  return tester.widget<ButtonStyleButton>(button.first).onPressed != null;
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('says what is deleted, lost and kept, at every viewport', (tester) async {
    await forEachViewport(
      tester,
      () => _wrap(_FakeAuthController(_account())),
      verify: (tester, size) async {
        expect(find.text('Deleted immediately'), findsOneWidget);
        expect(find.text('You will lose'), findsOneWidget);

        await _reveal(tester, find.text('Delete my account'));
        expect(find.text('Kept without your name'), findsWidgets);
        expect(find.text('Your password'), findsOneWidget);
        expect(find.text('Type DELETE to confirm'), findsOneWidget);
      },
    );
  });

  testWidgets('deletes only after the password and the word DELETE are entered', (tester) async {
    final controller = _FakeAuthController(_account());
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Delete my account'));

    expect(_deleteEnabled(tester), isFalse);

    await tester.enterText(find.widgetWithText(TextField, 'Your password'), 'my-secret-9');
    await tester.pump();
    expect(_deleteEnabled(tester), isFalse);

    await tester.enterText(find.widgetWithText(TextField, 'Type DELETE to confirm'), 'delete');
    await tester.pump();
    expect(_deleteEnabled(tester), isTrue);

    await _reveal(tester, find.text('Delete my account'));
    await tester.tap(find.text('Delete my account'));
    // Not pumpAndSettle: once deleted, the screen shows a skeleton whose
    // shimmer never settles (the router replaces it in the real app).
    await tester.pump();

    expect(controller.passwords, ['my-secret-9']);
  });

  testWidgets('an account without a password is asked only for the word DELETE', (tester) async {
    final controller = _FakeAuthController(_account(hasPassword: false));
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Delete my account'));

    expect(find.text('Your password'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await _reveal(tester, find.text('Delete my account'));
    await tester.tap(find.text('Delete my account'));
    // Not pumpAndSettle: once deleted, the screen shows a skeleton whose
    // shimmer never settles (the router replaces it in the real app).
    await tester.pump();

    expect(controller.passwords, [null]);
  });

  testWidgets('shows a wrong password on the password field and keeps the customer signed in', (tester) async {
    final controller = _FakeAuthController(
      _account(),
      failure: const ValidationAppException('The password is incorrect.', {
        'password': ['The password is incorrect.'],
      }),
    );
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Delete my account'));

    await tester.enterText(find.widgetWithText(TextField, 'Your password'), 'wrong');
    await tester.enterText(find.widgetWithText(TextField, 'Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await _reveal(tester, find.text('Delete my account'));
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('The password is incorrect.'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
  });

  testWidgets('a business account is sent to support instead of a delete button', (tester) async {
    await forEachViewport(
      tester,
      () => _wrap(_FakeAuthController(_account(canDeleteAccount: false))),
      verify: (tester, size) async {
        await _reveal(tester, find.text('This account runs a business'));
        expect(find.text('Delete my account'), findsNothing);
        expect(find.text('Type DELETE to confirm'), findsNothing);
        expect(find.textContaining('support@townshoppy.com'), findsOneWidget);
      },
    );
  });

  test('can_delete_account is read from the account payload and defaults to true', () {
    Map<String, dynamic> payload([Map<String, dynamic> extra = const {}]) => {
          'id': 1,
          'mobile_number': '+919990003001',
          'status': 'active',
          'roles': ['customer'],
          'customer_profile': null,
          ...extra,
        };

    expect(Account.fromJson(payload()).canDeleteAccount, isTrue);
    expect(Account.fromJson(payload({'can_delete_account': false})).canDeleteAccount, isFalse);
  });
}
