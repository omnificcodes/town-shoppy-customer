import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/auth/data/models/account.dart';

void main() {
  group('Account.fromJson', () {
    test('parses a customer account with a full customer_profile', () {
      final account = Account.fromJson({
        'id': 1,
        'mobile_number': '+919999900002',
        'status': 'active',
        'is_super_admin': false,
        'roles': ['customer'],
        'customer_profile': {
          'id': 5,
          'name': 'Jane Doe',
          'referral_code': 'ABC123',
          'status': 'active',
        },
      });

      expect(account.id, 1);
      expect(account.mobileNumber, '+919999900002');
      expect(account.isCustomer, isTrue);
      expect(account.displayName, 'Jane Doe');
      expect(account.customerProfile?.referralCode, 'ABC123');
    });

    test('falls back to mobile number for the display name when no name was captured', () {
      final account = Account.fromJson({
        'id': 2,
        'mobile_number': '+919999900003',
        'status': 'active',
        'is_super_admin': false,
        'roles': ['customer'],
        'customer_profile': {
          'id': 6,
          'name': null,
          'referral_code': 'XYZ789',
          'status': 'active',
        },
      });

      expect(account.displayName, '+919999900003');
    });

    test('handles a null customer_profile (non-customer account) without crashing', () {
      final account = Account.fromJson({
        'id': 3,
        'mobile_number': '+919999900004',
        'status': 'active',
        'is_super_admin': true,
        'roles': ['super_admin'],
        'customer_profile': null,
      });

      expect(account.customerProfile, isNull);
      expect(account.isCustomer, isFalse);
      expect(account.displayName, '+919999900004');
    });
  });
}
