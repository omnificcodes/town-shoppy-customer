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

/// No valid session. Shared by both the Login and Register screens for
/// their own in-flight/failure state — only one of them is ever actively
/// submitting at a time, and each screen starts its own submit by replacing
/// this with a fresh `AuthUnauthenticated(isSubmitting: true)`, which
/// naturally clears any error left over from the other screen.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final AppException? error;

  AuthUnauthenticated copyWith({bool? isSubmitting, AppException? error, bool clearError = false}) {
    return AuthUnauthenticated(
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
