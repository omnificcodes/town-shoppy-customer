import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';

class PasswordFormState {
  const PasswordFormState({this.isSubmitting = false, this.error, this.fieldErrors = const {}, this.success = false});

  final bool isSubmitting;
  final AppException? error;
  final Map<String, List<String>> fieldErrors;
  final bool success;

  PasswordFormState copyWith({bool? isSubmitting, AppException? error, bool clearError = false, Map<String, List<String>>? fieldErrors, bool? success}) {
    return PasswordFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      success: success ?? this.success,
    );
  }
}

/// Set-or-change password for Business mode's Security screen. After a
/// successful *set*, `/auth/me` is refreshed so `has_password` flips and
/// the screen offers "Change" from then on.
class PasswordController extends Notifier<PasswordFormState> {
  @override
  PasswordFormState build() => const PasswordFormState();

  Future<void> setPassword(String password) => _run(() => ref.read(authRepositoryProvider).setPassword(password: password), refresh: true);

  Future<void> changePassword({required String currentPassword, required String password}) =>
      _run(() => ref.read(authRepositoryProvider).changePassword(currentPassword: currentPassword, password: password));

  Future<void> _run(Future<void> Function() action, {bool refresh = false}) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true, fieldErrors: const {});
    try {
      await action();
      if (refresh) await ref.read(authControllerProvider.notifier).refreshAccount();
      state = state.copyWith(isSubmitting: false, success: true);
    } on AppException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e, fieldErrors: e is ValidationAppException ? e.fieldErrors : const {});
    }
  }
}

final passwordControllerProvider = NotifierProvider.autoDispose<PasswordController, PasswordFormState>(PasswordController.new);
