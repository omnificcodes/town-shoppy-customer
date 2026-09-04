import '../../../core/errors/app_exception.dart';

/// Deliberately separate from [AuthState] -- resetting a forgotten password
/// never signs the caller in (the backend's own `resetPassword` returns no
/// token, see `AuthRepository.resetPassword`'s docblock), so it has no
/// "authenticated" outcome to model.
sealed class PasswordResetState {
  const PasswordResetState();
}

class PasswordResetIdle extends PasswordResetState {
  const PasswordResetIdle({this.error});

  final AppException? error;
}

class PasswordResetSubmitting extends PasswordResetState {
  const PasswordResetSubmitting();
}
