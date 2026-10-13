import 'dart:async';

import 'package:customer/core/app_mode/app_mode.dart';
import 'package:customer/core/app_mode/app_mode_controller.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/auth_repository.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/presentation/account_sync_on_resume.dart';
import 'package:customer/features/business/application/merchant_registration_controller.dart';
import 'package:customer/features/business/data/business_merchant_repository.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/data/models/merchant_registration_input.dart';
import 'package:customer/features/notifications/application/push_notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_controller_test.dart' show FakeAuthRepository, FakeSecureStorageService;

/// The reported bug: an owner, back in Customer mode, is still offered
/// "Register your business" until they sign out and in again. The account
/// in memory was read once per session, so a business that did not arrive
/// through this app's own post-registration refresh stayed invisible.
Account _account({required bool owner}) => Account.fromJson({
  'id': 1,
  'mobile_number': '+919812345600',
  'status': 'active',
  'is_super_admin': false,
  'roles': ['customer', if (owner) 'merchant_owner'],
  'customer_profile': {'id': 1, 'name': 'New Owner', 'referral_code': 'OWNER001', 'status': 'active'},
  if (owner)
    'merchant_owner_profiles': [
      {'id': 1, 'merchant_id': 9, 'status': 'active'},
    ],
});

class _FakeMerchantRepository extends BusinessMerchantRepository {
  _FakeMerchantRepository() : super(Dio());

  @override
  Future<BusinessMerchant> register(MerchantRegistrationInput input) async => BusinessMerchant.fromJson({
    'id': 9,
    'name': 'New Bakery',
    'status': 'pending',
    'accepts_town_coin': false,
    'is_featured': false,
  });
}

/// Push registration needs Firebase; nothing here is about push.
class _NoPush extends PushNotificationService {
  @override
  Future<void> registerForCurrentAccount() async {}

  @override
  Future<void> deregisterCurrentDevice() async {}
}

/// A `/auth/me` that answers only when the test says so.
class _SlowMeRepository extends FakeAuthRepository {
  final pending = Completer<Account>();

  @override
  Future<Account> me() {
    meCallCount++;
    return pending.future;
  }
}

MerchantRegistrationInput _input({String? logoUrl, String? coverImageUrl}) => const MerchantRegistrationInput(
  name: 'New Bakery',
  ownerName: 'New Owner',
  associationId: 1,
  categoryId: 1,
  addressLine: 'Market Road',
  latitude: 10.5,
  longitude: 76.2,
  discountRate: 10,
);

ProviderContainer _container(FakeAuthRepository auth) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
      businessMerchantRepositoryProvider.overrideWithValue(_FakeMerchantRepository()),
      pushNotificationServiceProvider.overrideWith(_NoPush.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Account? _accountIn(ProviderContainer container) {
  final state = container.read(authControllerProvider);
  return state is AuthAuthenticated ? state.account : null;
}

/// Signs in as a plain customer, the way a returning user starts a session.
Future<void> _signInAsCustomer(ProviderContainer container, FakeAuthRepository auth) async {
  container.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero); // cold-start restore: nothing stored
  auth.queueLoginSuccess(AuthResult(account: _account(owner: false), token: 't'));
  await container.read(authControllerProvider.notifier).login('9812345600', 'secret123');
  expect(_accountIn(container)?.hasMerchantAccess, isFalse);
}

void main() {
  test('registering in this app leaves an account that holds the business, through a mode switch', () async {
    final auth = FakeAuthRepository();
    final container = _container(auth);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);

    auth.queueRegisterSuccess(AuthResult(account: _account(owner: false), token: 't'));
    // submit()'s own refresh, then one re-read per mode switch below.
    auth
      ..queueMeSuccess(_account(owner: true))
      ..queueMeSuccess(_account(owner: true))
      ..queueMeSuccess(_account(owner: true));

    final sub = container.listen(merchantRegistrationControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container
        .read(merchantRegistrationControllerProvider.notifier)
        .submit(
          buildInput: _input,
          createAccount: (mobileNumber: '9812345600', name: 'New Owner', password: 'secret123'),
        );
    expect(_accountIn(container)?.hasMerchantAccess, isTrue);

    await container.read(appModeControllerProvider.notifier).select(AppMode.customer);
    await container.read(authControllerProvider.notifier).syncAccount();
    await pumpEventQueue();

    expect(_accountIn(container)?.hasMerchantAccess, isTrue);
  });

  test('a business the app did not register itself shows up at the next mode switch', () async {
    final auth = FakeAuthRepository();
    final container = _container(auth);
    await _signInAsCustomer(container, auth);

    // Registered elsewhere -- the merchant web portal, another tab, another
    // device. The backend knows; the account in memory does not.
    auth.queueMeSuccess(_account(owner: true));

    await container.read(appModeControllerProvider.notifier).select(AppMode.customer);
    await pumpEventQueue();

    expect(auth.meCallCount, 1, reason: 'the switch itself re-reads the account');
    expect(_accountIn(container)?.hasMerchantAccess, isTrue);
  });

  test('re-reads are coalesced and throttled, and a forced one still goes through', () async {
    final auth = FakeAuthRepository();
    final container = _container(auth);
    await _signInAsCustomer(container, auth);
    final controller = container.read(authControllerProvider.notifier);

    // Signing in just read the account, so an ordinary re-read is skipped.
    await controller.syncAccount();
    expect(auth.meCallCount, 0);

    // A forced one is not, and two at once share a single request.
    auth.queueMeSuccess(_account(owner: true));
    await Future.wait([controller.syncAccount(force: true), controller.syncAccount(force: true)]);
    expect(auth.meCallCount, 1);
    expect(_accountIn(container)?.hasMerchantAccess, isTrue);
  });

  test('a failed re-read keeps the account already in memory', () async {
    final auth = FakeAuthRepository();
    final container = _container(auth);
    await _signInAsCustomer(container, auth);

    auth.queueMeError(const NetworkException('offline'));
    await container.read(authControllerProvider.notifier).syncAccount(force: true);

    expect(_accountIn(container), isNotNull);
    expect(_accountIn(container)?.hasMerchantAccess, isFalse);
  });

  test('signing out never triggers a re-read, and a late answer cannot sign the user back in', () async {
    final auth = _SlowMeRepository();
    final container = _container(auth);
    await _signInAsCustomer(container, auth);
    final controller = container.read(authControllerProvider.notifier);

    // A re-read is out when the user signs out.
    final sync = controller.syncAccount(force: true);
    await controller.logout();
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(auth.meCallCount, 1, reason: 'sign-out clears the mode, which is not a switch');

    auth.pending.complete(_account(owner: true));
    await sync;

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  testWidgets('returning to the app re-reads the account', (tester) async {
    final auth = FakeAuthRepository();
    final container = _container(auth);
    await tester.runAsync(() => _signInAsCustomer(container, auth));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AccountSyncOnResume(child: SizedBox()),
      ),
    );

    auth.queueMeSuccess(_account(owner: true));
    // Long enough that the resume is not throttled away.
    container.read(authControllerProvider.notifier).debugBackdateLastSync(AuthController.syncInterval * 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(auth.meCallCount, 1);
    expect(_accountIn(container)?.hasMerchantAccess, isTrue);
  });

  test('a new business is registered open 9 to 6 every day', () {
    final hours = _input().toJson()['business_hours'] as Map<String, dynamic>;
    expect(hours.keys, ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']);
    for (final day in hours.values) {
      expect(day, {'open': '09:00', 'close': '18:00', 'closed': false});
    }
  });
}
