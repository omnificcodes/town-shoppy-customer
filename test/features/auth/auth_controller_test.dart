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
/// queued responses let each test arrange the exact backend sequence a real
/// registration flow (OTP verify -> "name required" -> resubmit) would
/// produce, without a live backend.
class FakeAuthRepository implements AuthRepository {
  final List<Object> _verifyResponses = [];
  final List<Map<String, String?>> verifyCalls = [];
  int verifyCallCount = 0;
  Completer<VerifyOtpResult>? _pending;

  void queueVerifySuccess(VerifyOtpResult result) => _verifyResponses.add(result);
  void queueVerifyError(AppException error) => _verifyResponses.add(error);

  /// Makes the *next* [verifyOtp] call hang until the returned completer is
  /// completed — lets a test observe the in-flight "submitting" state
  /// before the request resolves, and exercise duplicate-submission
  /// prevention while a real request would still be in flight.
  Completer<VerifyOtpResult> queueVerifyPending() {
    final completer = Completer<VerifyOtpResult>();
    _pending = completer;
    return completer;
  }

  @override
  Future<OtpRequestResult> requestOtp({required String mobileNumber, String? channel}) async {
    return const OtpRequestResult(otpRequestId: 1, expiresInSeconds: 300, channelUsed: 'sms', debugCode: '123456');
  }

  @override
  Future<VerifyOtpResult> verifyOtp({required int otpRequestId, required String code, String? name, String? referralCode}) async {
    verifyCallCount++;
    verifyCalls.add({'name': name, 'referralCode': referralCode});
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      return pending.future;
    }
    final next = _verifyResponses.removeAt(0);
    if (next is AppException) throw next;
    return next as VerifyOtpResult;
  }

  @override
  Future<Account> me() async => throw UnimplementedError();

  @override
  Future<void> logout() async {}
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

  Future<AuthController> setUpVerifying() async {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero); // let the initial _restoreSession() settle

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.requestOtp('9999900002');
    await notifier.verifyOtp('123456'); // no name/referralCode -> backend will say "name required"
    return notifier;
  }

  setUp(() {
    fakeRepository = FakeAuthRepository();
  });

  group('registration completion (referral-code entry)', () {
    test('a new account is routed to AuthProfileRequired when the backend requires a name', () async {
      fakeRepository.queueVerifyError(const ValidationAppException('Validation failed.', {
        'name': ['Name is required to complete registration.'],
      }));

      await setUpVerifying();

      expect(container.read(authControllerProvider), isA<AuthProfileRequired>());
    });

    test('completing registration without a referral code sends referralCode as null', () async {
      fakeRepository.queueVerifyError(const ValidationAppException('Validation failed.', {
        'name': ['Name is required to complete registration.'],
      }));
      final notifier = await setUpVerifying();

      fakeRepository.queueVerifySuccess(VerifyOtpResult(account: _newAccount(), token: 'tok', isNewAccount: true));
      await notifier.completeRegistration(name: 'Jane Doe');

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(fakeRepository.verifyCalls.last, {'name': 'Jane Doe', 'referralCode': null});
    });

    test('a valid referral code is passed through and successfully applied', () async {
      fakeRepository.queueVerifyError(const ValidationAppException('Validation failed.', {
        'name': ['Name is required to complete registration.'],
      }));
      final notifier = await setUpVerifying();

      fakeRepository.queueVerifySuccess(VerifyOtpResult(account: _newAccount(), token: 'tok', isNewAccount: true));
      await notifier.completeRegistration(name: 'Jane Doe', referralCode: 'ABC123');

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(fakeRepository.verifyCalls.last, {'name': 'Jane Doe', 'referralCode': 'ABC123'});
    });

    test('a backend validation error on resubmit keeps AuthProfileRequired with the error attached', () async {
      fakeRepository.queueVerifyError(const ValidationAppException('Validation failed.', {
        'name': ['Name is required to complete registration.'],
      }));
      final notifier = await setUpVerifying();

      fakeRepository.queueVerifyError(const ValidationAppException('Validation failed.', {
        'name': ['The name field must be at least 2 characters.'],
      }));
      await notifier.completeRegistration(name: 'J');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthProfileRequired>());
      expect((state as AuthProfileRequired).isSubmitting, isFalse);
      expect(state.error, isA<ValidationAppException>());
    });

    test('shows a submitting state while the request is in flight, and blocks a duplicate submission', () async {
      fakeRepository.queueVerifyError(const ValidationAppException('Validation failed.', {
        'name': ['Name is required to complete registration.'],
      }));
      final notifier = await setUpVerifying();

      final completer = fakeRepository.queueVerifyPending();
      final pendingFirst = notifier.completeRegistration(name: 'Jane Doe');
      await Future<void>.delayed(Duration.zero); // let the async gap up to the network call happen

      expect(
        (container.read(authControllerProvider) as AuthProfileRequired).isSubmitting,
        isTrue,
        reason: 'state must flip to isSubmitting immediately, before the network call resolves',
      );

      // A second submission attempt while the first is in flight must be a
      // no-op — the count stays at 2 (1 from setUpVerifying's initial
      // verifyOtp call, 1 from the in-flight completeRegistration call
      // above), never reaching 3.
      await notifier.completeRegistration(name: 'Someone Else');
      expect(fakeRepository.verifyCallCount, 2);

      completer.complete(VerifyOtpResult(account: _newAccount(), token: 'tok', isNewAccount: true));
      await pendingFirst;

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    });
  });
}
