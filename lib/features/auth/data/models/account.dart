import 'customer_profile.dart';

/// Mirrors `App\Domain\Auth\Http\Resources\AccountResource`. The customer
/// app only ever expects `customer_profile` to be populated for its own
/// signed-in account (a `Role.Customer` is resolved purely from whether
/// `customerProfile` exists — `Account::activeRoles()`), but the other
/// role-profile arrays are parsed too since the same `/auth/me` endpoint is
/// shared platform-wide and could theoretically return them for a
/// multi-role account (a merchant owner who is also a customer).
class Account {
  const Account({
    required this.id,
    required this.mobileNumber,
    required this.status,
    required this.isSuperAdmin,
    required this.roles,
    required this.customerProfile,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int,
      mobileNumber: json['mobile_number'] as String,
      status: json['status'] as String,
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      roles: (json['roles'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      customerProfile: json['customer_profile'] != null
          ? CustomerProfile.fromJson(json['customer_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  final int id;
  final String mobileNumber;
  final String status;
  final bool isSuperAdmin;
  final List<String> roles;
  final CustomerProfile? customerProfile;

  bool get isCustomer => roles.contains('customer');

  /// Display name for the greeting — falls back to the mobile number when
  /// no name was captured at registration (section 21: "do not assume a
  /// name exists").
  String get displayName => customerProfile?.name?.trim().isNotEmpty == true ? customerProfile!.name!.trim() : mobileNumber;
}
