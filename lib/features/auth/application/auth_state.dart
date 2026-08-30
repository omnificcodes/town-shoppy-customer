import '../../../core/errors/app_exception.dart';
import '../data/models/account.dart';

/// Explicit authentication states (section 62 of the phase brief: "avoid
/// boolean-only auth state"). Each screen watches this directly instead of
/// re-deriving its own loading/error booleans.
sealed class AuthState {
  const AuthState();
}

/// App just started — restoring a previously stored session, if any.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// No valid session. [isRequestingOtp] and [error] cover the mobile-number
/// entry screen's own in-flight/failure states without a separate state
/// class for what is still, structurally, "not signed in."
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.isRequestingOtp = false, this.error});

  final bool isRequestingOtp;
  final AppException? error;

  AuthUnauthenticated copyWith({bool? isRequestingOtp, AppException? error, bool clearError = false}) {
    return AuthUnauthenticated(
      isRequestingOtp: isRequestingOtp ?? this.isRequestingOtp,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// An OTP has been requested and is awaiting verification.
class AuthOtpSent extends AuthState {
  const AuthOtpSent({
    required this.otpRequestId,
    required this.mobileNumber,
    required this.expiresAt,
    required this.channelUsed,
    this.debugCode,
    this.isVerifying = false,
    this.isResending = false,
    this.error,
  });

  final int otpRequestId;
  final String mobileNumber;
  final DateTime expiresAt;
  final String channelUsed;
  final String? debugCode;
  final bool isVerifying;
  final bool isResending;
  final AppException? error;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  AuthOtpSent copyWith({
    int? otpRequestId,
    DateTime? expiresAt,
    String? channelUsed,
    String? debugCode,
    bool clearDebugCode = false,
    bool? isVerifying,
    bool? isResending,
    AppException? error,
    bool clearError = false,
  }) {
    return AuthOtpSent(
      otpRequestId: otpRequestId ?? this.otpRequestId,
      mobileNumber: mobileNumber,
      expiresAt: expiresAt ?? this.expiresAt,
      channelUsed: channelUsed ?? this.channelUsed,
      debugCode: clearDebugCode ? null : (debugCode ?? this.debugCode),
      isVerifying: isVerifying ?? this.isVerifying,
      isResending: isResending ?? this.isResending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The OTP was correct, but this is a genuinely new account and the
/// backend rejected registration because it still needs a name
/// (`AuthService::completeOtpAuthentication` — `name` is required to create
/// a `CustomerProfile`). This is also the only moment a referral code can
/// ever be applied (`OtpVerifyRequest`'s `referral_code` — accepted only on
/// this same new-account creation, ignored for an existing account). The
/// OTP itself is not re-consumed by retrying: `OtpService::verify()` is
/// explicitly idempotent for a caller who still presents the correct code,
/// so resubmitting [otpRequestId]/[code] alongside a name is safe.
class AuthProfileRequired extends AuthState {
  const AuthProfileRequired({
    required this.otpRequestId,
    required this.code,
    required this.mobileNumber,
    this.isSubmitting = false,
    this.error,
  });

  final int otpRequestId;
  final String code;
  final String mobileNumber;
  final bool isSubmitting;
  final AppException? error;

  AuthProfileRequired copyWith({bool? isSubmitting, AppException? error, bool clearError = false}) {
    return AuthProfileRequired(
      otpRequestId: otpRequestId,
      code: code,
      mobileNumber: mobileNumber,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Signed in.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.account, {this.isLoggingOut = false});

  final Account account;
  final bool isLoggingOut;
}

/// The backend rejected the stored token (401) — distinct from
/// [AuthUnauthenticated] purely so the login screen can show "your session
/// expired" once instead of silently looking like a fresh app launch
/// (section 38/65).
class AuthSessionExpired extends AuthState {
  const AuthSessionExpired();
}
