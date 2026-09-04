import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/auth_repository.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/otp_request_result.dart';

Account _newAccount() {
  return Account.fromJson({
    'id': 1,
    'mobile_number': '+919999900002',
    'status': 'active',
    'is_super_admin': false,
    'roles': ['customer'],
    'customer_profile': {'id': 1, 'name': 'Jane Doe', 'referral_code': 'JANE001', 'status': 'active'},
  });
}

/// A scripted fake, mirroring the phase-1 `FakeAuthRepository` pattern —
/// queued responses let each test arrange the exact backend outcome a real
/// login/register call would produce, without a live backend.
class FakeAuthRepository implements AuthRepository {
  final List<Object> _loginResponses = [];
  final List<Object> _registerResponses = [];
  int loginCallCount = 0;
  int registerCallCount = 0;
  Map<String, String?>? lastRegisterCall;
  Completer<AuthResult>? _pendingLogin;

  void queueLoginSuccess(AuthResult result) => _loginResponses.add(result);
  void queueLoginError(AppException error) => _loginResponses.add(error);
  void queueRegisterSuccess(AuthResult result) => _registerResponses.add(result);
  void queueRegisterError(AppException error) => _registerResponses.add(error);

  /// Makes the *next* [login] call hang until the returned completer is
  /// completed — lets a test observe the in-flight "submitting" state
  /// before the request resolves, and exercise duplicate-submission
  /// prevention while a real request would still be in flight.
  Completer<AuthResult> queueLoginPending() {
    final completer = Completer<AuthResult>();
    _pendingLogin = completer;
    return completer;
  }

  @override
  Future<AuthResult> login({required String mobileNumber, required String password}) async {
    loginCallCount++;
    final pending = _pendingLogin;
    if (pending != null) {
      _pendingLogin = null;
      return pending.future;
    }
    final next = _loginResponses.removeAt(0);
    if (next is AppException) throw next;
    return next as AuthResult;
  }

  @override
  Future<AuthResult> register({required String mobileNumber, required String name, required String password, String? referralCode}) async {
    registerCallCount++;
    lastRegisterCall = {'name': name, 'referralCode': referralCode};
    final next = _registerResponses.removeAt(0);
    if (next is AppException) throw next;
    return next as AuthResult;
  }

  @override
  Future<Account> me() async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<OtpRequestResult> forgotPassword({required String mobileNumber, String? channel}) async =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String mobileNumber,
    required int otpRequestId,
    required String code,
    required String password,
  }) async => throw UnimplementedError();
}

class FakeSecureStorageService implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);
}

void main() {
  late FakeAuthRepository fakeRepository;
  late ProviderContainer container;

  AuthController setUpController() {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    return container.read(authControllerProvider.notifier);
  }

  setUp(() {
    fakeRepository = FakeAuthRepository();
  });

  group('login', () {
    test('a successful login reaches AuthAuthenticated', () async {
      fakeRepository.queueLoginSuccess(AuthResult(account: _newAccount(), token: 'tok'));
      final notifier = setUpController();
      await Future<void>.delayed(Duration.zero); // let the initial _restoreSession() settle

      await notifier.login('9999900002', 'a-real-password');

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(fakeRepository.loginCallCount, 1);
    });

    test('an invalid-credentials error is attached to AuthUnauthenticated', () async {
      fakeRepository.queueLoginError(const ValidationAppException('Validation failed.', {
        'mobile_number': ['These credentials do not match our records.'],
      }));
      final notifier = setUpController();
      await Future<void>.delayed(Duration.zero);

      await notifier.login('9999900002', 'wrong-password');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).error, isA<ValidationAppException>());
      expect(state.isSubmitting, isFalse);
    });

    test('shows a submitting state while the request is in flight, and blocks a duplicate submission', () async {
      final notifier = setUpController();
      await Future<void>.delayed(Duration.zero);

      final completer = fakeRepository.queueLoginPending();
      final pendingFirst = notifier.login('9999900002', 'a-real-password');
      await Future<void>.delayed(Duration.zero); // let the async gap up to the network call happen

      expect(
        (container.read(authControllerProvider) as AuthUnauthenticated).isSubmitting,
        isTrue,
        reason: 'state must flip to isSubmitting immediately, before the network call resolves',
      );

      // A second submission attempt while the first is in flight must be a
      // no-op — the count stays at 1.
      await notifier.login('9999900002', 'a-real-password');
      expect(fakeRepository.loginCallCount, 1);

      completer.complete(AuthResult(account: _newAccount(), token: 'tok'));
      await pendingFirst;

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    });
  });

  group('register', () {
    test('a successful registration reaches AuthAuthenticated', () async {
      fakeRepository.queueRegisterSuccess(AuthResult(account: _newAccount(), token: 'tok'));
      final notifier = setUpController();
      await Future<void>.delayed(Duration.zero);

      await notifier.register('9999900002', 'Jane Doe', 'a-brand-new-password');

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(fakeRepository.lastRegisterCall, {'name': 'Jane Doe', 'referralCode': null});
    });

    test('an optional referral code is passed through', () async {
      fakeRepository.queueRegisterSuccess(AuthResult(account: _newAccount(), token: 'tok'));
      final notifier = setUpController();
      await Future<void>.delayed(Duration.zero);

      await notifier.register('9999900002', 'Jane Doe', 'a-brand-new-password', referralCode: 'ABC123');

      expect(fakeRepository.lastRegisterCall, {'name': 'Jane Doe', 'referralCode': 'ABC123'});
    });

    test('a backend validation error (e.g. mobile number already registered) is attached to AuthUnauthenticated', () async {
      fakeRepository.queueRegisterError(const ValidationAppException('Validation failed.', {
        'mobile_number': ['An account already exists for this mobile number. Try signing in instead.'],
      }));
      final notifier = setUpController();
      await Future<void>.delayed(Duration.zero);

      await notifier.register('9999900002', 'Jane Doe', 'a-brand-new-password');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).error, isA<ValidationAppException>());
    });
  });

  group('clearError', () {
    test('resets AuthUnauthenticated back to error-free, e.g. when navigating between Login and Register', () async {
      fakeRepository.queueLoginError(const ValidationAppException('Validation failed.', {
        'mobile_number': ['These credentials do not match our records.'],
      }));
      final notifier = setUpController();
      await Future<void>.delayed(Duration.zero);

      await notifier.login('9999900002', 'wrong-password');
      expect((container.read(authControllerProvider) as AuthUnauthenticated).error, isNotNull);

      notifier.clearError();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).error, isNull);
    });
  });
}
