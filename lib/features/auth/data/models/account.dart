import 'customer_profile.dart';
import 'merchant_profile_ref.dart';

/// Mirrors `App\Domain\Auth\Http\Resources\AccountResource`. One account can
/// carry several role profiles at once -- the normal "shop owner who also
/// shops" case -- and `/auth/me` returns all of them, so this model keeps
/// the merchant profile arrays too: they are what decide whether the app
/// offers Business mode at all (see `hasMerchantAccess`).
class Account {
  const Account({
    required this.id,
    required this.mobileNumber,
    required this.status,
    required this.isSuperAdmin,
    required this.roles,
    required this.customerProfile,
    this.email,
    this.hasPassword = true,
    this.canDeleteAccount = true,
    this.merchantOwnerProfiles = const [],
    this.merchantStaffProfiles = const [],
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
      email: json['email'] as String?,
      hasPassword: json['has_password'] as bool? ?? true,
      canDeleteAccount: json['can_delete_account'] as bool? ?? true,
      merchantOwnerProfiles: _profiles(json['merchant_owner_profiles']),
      merchantStaffProfiles: _profiles(json['merchant_staff_profiles']),
    );
  }

  static List<MerchantProfileRef> _profiles(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => MerchantProfileRef.fromJson(e as Map<String, dynamic>)).toList();
  }

  final int id;
  final String mobileNumber;
  final String status;
  final bool isSuperAdmin;
  final List<String> roles;
  final CustomerProfile? customerProfile;
  final String? email;

  /// `has_password` -- drives Business mode's Security screen ("Set" vs
  /// "Change" password). Defaults to true when absent so an older payload
  /// never offers "set a password" to someone who already has one.
  final bool hasPassword;

  /// `can_delete_account` -- false for an account that runs a business or
  /// holds an admin role: the server closes those through support, so the
  /// Delete account screen explains that instead of offering the button.
  /// Defaults to true when absent; the server refuses on its own anyway.
  final bool canDeleteAccount;

  final List<MerchantProfileRef> merchantOwnerProfiles;
  final List<MerchantProfileRef> merchantStaffProfiles;

  bool get isCustomer => roles.contains('customer');

  /// Owner wins over staff, one merchant per account -- the same
  /// `resolveMyMerchantId()` rule the merchant web app applies.
  int? get activeMerchantId {
    for (final p in merchantOwnerProfiles) {
      if (p.isActive) return p.merchantId;
    }
    for (final p in merchantStaffProfiles) {
      if (p.isActive) return p.merchantId;
    }
    return null;
  }

  bool get isMerchantOwner => merchantOwnerProfiles.any((p) => p.isActive);

  bool get isMerchantStaff => !isMerchantOwner && merchantStaffProfiles.any((p) => p.isActive);

  /// Whether this account may enter Business mode at all -- the router's
  /// only input for showing the Customer/Business chooser.
  bool get hasMerchantAccess => activeMerchantId != null;

  /// Display name for the greeting — falls back to the mobile number when
  /// no name was captured at registration (section 21: "do not assume a
  /// name exists").
  String get displayName => customerProfile?.name?.trim().isNotEmpty == true ? customerProfile!.name!.trim() : mobileNumber;
}
