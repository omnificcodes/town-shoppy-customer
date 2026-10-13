import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/direct_pos_controller.dart';
import 'package:customer/features/business/data/direct_pos_repository.dart';
import 'package:customer/features/business/data/models/direct_pos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _account = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['merchant_owner'],
  customerProfile: null,
  merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

class _FakeDirectPosRepository implements DirectPosRepository {
  Object? previewResponse;
  Object? submitResponse;
  Object? lookupResponse;
  final submittedKeys = <String>[];
  Map<String, dynamic>? lastIdentity;

  @override
  Future<CustomerLookupResult> lookupCustomer({required int merchantId, required String mobileNumber}) async {
    final r = lookupResponse;
    if (r is AppException) throw r;
    return r as CustomerLookupResult;
  }

  @override
  Future<DirectPosPreview> preview({required int merchantId, required DirectPosIdentity identity, required double billAmount, int? branchId}) async {
    lastIdentity = identity.toJson();
    final r = previewResponse;
    if (r is AppException) throw r;
    return r as DirectPosPreview;
  }

  @override
  Future<DirectPosResult> submit({
    required int merchantId,
    required DirectPosIdentity identity,
    required double billAmount,
    required bool redeem,
    required String idempotencyKey,
    int? branchId,
    String? billReference,
    int? scratchCardId,
    int? stampCardId,
  }) async {
    submittedKeys.add(idempotencyKey);
    lastIdentity = identity.toJson();
    final r = submitResponse;
    if (r is AppException) throw r;
    return r as DirectPosResult;
  }
}

DirectPosResult _result() => DirectPosResult.fromJson({
      'purchase': {'id': 77, 'merchant_id': 5, 'bill_amount': 500, 'currency': 'INR', 'status': 'recorded', 'coins_awarded': 50},
      'redeemed_coins': 100,
      'discount_amount': '10',
      'payable_amount': '490',
    }, meta: {'duplicate_warning': 'Possible duplicate.'});

void main() {
  late _FakeDirectPosRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeDirectPosRepository();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        directPosRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose: keep the controller alive between reads, as a screen would.
    container.listen(directPosControllerProvider, (_, _) {});
  });

  DirectPosController notifier() => container.read(directPosControllerProvider.notifier);
  DirectPosState state() => container.read(directPosControllerProvider);

  test('rotates the idempotency key when the amount changes, but not on a name edit', () {
    final n = notifier();
    n.setMobile('9876543210');
    final k1 = state().idempotencyKey;
    n.setBillAmount('500');
    final k2 = state().idempotencyKey;
    n.setCustomerName('Asha');
    final k3 = state().idempotencyKey;

    expect(k2, isNot(k1));
    expect(k3, k2);
  });

  test('a 422 on preview for a typed mobile switches the form into inline registration', () async {
    repo.previewResponse = const ValidationAppException('No account', {'customer_mobile_number': ['No Town Shoppy customer account is registered for this mobile number.']});
    final n = notifier();
    n.setMobile('9876543210');
    n.setBillAmount('500');

    await n.previewDiscount();

    expect(state().mustRegister, isTrue);
    expect(state().error, isNull);
  });

  test('a successful preview parses the string money fields', () async {
    repo.previewResponse = DirectPosPreview.fromJson({'bill_amount': 500, 'customer_name': 'Asha', 'available_balance': 200, 'max_discount_amount': '50', 'max_redeemable_coins': 200, 'payable_amount': '450'});
    final n = notifier();
    n.setMethod(DirectPosMethod.qr);
    n.setQrToken('abc');
    n.setBillAmount('500');

    await n.previewDiscount();

    expect(state().preview?.payableAmount, 450);
    expect(repo.lastIdentity, {'customer_qr_token': 'abc'});
  });

  test('submit sends the customer name only when registering, and surfaces the duplicate warning', () async {
    repo.lookupResponse = CustomerLookupResult.fromJson({'registered': false, 'id': null, 'name': null, 'mobile_number': '+919876543210', 'purchase_count': 0, 'total_spent': 0, 'last_purchase_at': null});
    repo.submitResponse = _result();
    final n = notifier();
    n.setMobile('9876543210');
    await n.lookup();
    n.setCustomerName('Asha');
    n.setBillAmount('500');

    await n.submit();

    expect(repo.lastIdentity, {'customer_mobile_number': '9876543210', 'customer_name': 'Asha'});
    expect(state().result?.duplicateWarning, 'Possible duplicate.');
    expect(state().result?.discountAmount, 10);
    expect(repo.submittedKeys.single, state().idempotencyKey);
  });

  test('a 402 becomes a subscription banner, not a generic error', () async {
    repo.submitResponse = const UnknownAppException('Please select a package to use this feature.', 402);
    final n = notifier();
    n.setMethod(DirectPosMethod.qr);
    n.setQrToken('abc');
    n.setBillAmount('500');

    await n.submit();

    expect(state().subscriptionReason, 'no_subscription');
    expect(state().result, isNull);
  });
}
