import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/otp_request_result.dart';
import 'password_reset_state.dart';

/// Drives both steps of the forgot-password flow -- [requestOtp] (Step 1,
/// `ForgotPasswordScreen`) and [reset] (Step 2, `ResetPasswordScreen`).
/// Same isSubmitting-as-a-sealed-subtype shape `AuthController` uses for
/// login/register, so both screens read loading/error state identically.
class PasswordResetController extends Notifier<PasswordResetState> {
  late final AuthRepository _repository;

  @override
  PasswordResetState build() {
    _repository = ref.watch(authRepositoryProvider);
    return const PasswordResetIdle();
  }

  bool get _isSubmitting => state is PasswordResetSubmitting;

  Future<OtpRequestResult?> requestOtp(String mobileNumber) async {
    if (_isSubmitting) return null;

    state = const PasswordResetSubmitting();
    try {
      final result = await _repository.forgotPassword(mobileNumber: mobileNumber);
      state = const PasswordResetIdle();
      return result;
    } on AppException catch (e) {
      state = PasswordResetIdle(error: e);
      return null;
    }
  }

  Future<bool> reset({
    required String mobileNumber,
    required int otpRequestId,
    required String code,
    required String password,
  }) async {
    if (_isSubmitting) return false;

    state = const PasswordResetSubmitting();
    try {
      await _repository.resetPassword(mobileNumber: mobileNumber, otpRequestId: otpRequestId, code: code, password: password);
      state = const PasswordResetIdle();
      return true;
    } on AppException catch (e) {
      state = PasswordResetIdle(error: e);
      return false;
    }
  }

  /// Called when either screen first mounts, so navigating back and forth
  /// never shows a stale error from the other step.
  void clearError() {
    if (state is PasswordResetIdle) state = const PasswordResetIdle();
  }
}

final passwordResetControllerProvider = NotifierProvider<PasswordResetController, PasswordResetState>(
  PasswordResetController.new,
);
