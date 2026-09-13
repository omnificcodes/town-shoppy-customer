import 'package:customer/features/auth/data/models/account.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _base() => {
      'id': 7,
      'mobile_number': '+919999900007',
      'status': 'active',
      'is_super_admin': false,
      'has_password': false,
      'roles': ['customer'],
      'customer_profile': {'id': 3, 'name': 'Asha', 'referral_code': 'ASHA01', 'status': 'active'},
    };

void main() {
  test('a plain customer has no merchant access', () {
    final account = Account.fromJson(_base());
    expect(account.hasMerchantAccess, isFalse);
    expect(account.activeMerchantId, isNull);
    expect(account.isMerchantOwner, isFalse);
    expect(account.isMerchantStaff, isFalse);
    expect(account.hasPassword, isFalse);
  });

  test('an active owner profile wins over a staff profile (one merchant per account)', () {
    final account = Account.fromJson({
      ..._base(),
      'merchant_owner_profiles': [
        {'id': 1, 'merchant_id': 42, 'status': 'active'},
      ],
      'merchant_staff_profiles': [
        {'id': 2, 'merchant_id': 99, 'status': 'active'},
      ],
    });
    expect(account.activeMerchantId, 42);
    expect(account.isMerchantOwner, isTrue);
    expect(account.isMerchantStaff, isFalse);
  });

  test('a staff-only account resolves the staff merchant', () {
    final account = Account.fromJson({
      ..._base(),
      'merchant_owner_profiles': const [],
      'merchant_staff_profiles': [
        {'id': 2, 'merchant_id': 99, 'status': 'active'},
      ],
    });
    expect(account.activeMerchantId, 99);
    expect(account.isMerchantOwner, isFalse);
    expect(account.isMerchantStaff, isTrue);
  });

  test('inactive profiles grant nothing', () {
    final account = Account.fromJson({
      ..._base(),
      'merchant_owner_profiles': [
        {'id': 1, 'merchant_id': 42, 'status': 'suspended'},
      ],
    });
    expect(account.hasMerchantAccess, isFalse);
  });

  test('the older payload shape (no profile arrays) still parses', () {
    final json = _base()..remove('has_password');
    final account = Account.fromJson(json);
    expect(account.merchantOwnerProfiles, isEmpty);
    expect(account.hasPassword, isTrue);
  });
}
