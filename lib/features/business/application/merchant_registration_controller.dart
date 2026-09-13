import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/business_merchant_repository.dart';
import '../data/models/business_merchant.dart';
import '../data/models/merchant_registration_input.dart';

class MerchantRegistrationState {
  const MerchantRegistrationState({
    this.isSubmitting = false,
    this.error,
    this.fieldErrors = const {},
    this.registered,
    this.imageUploadFailed = false,
  });

  final bool isSubmitting;
  final AppException? error;

  /// Backend 422 field errors keyed by the API field name, so the form can
  /// pin "Association is required." under the right control.
  final Map<String, List<String>> fieldErrors;

  /// Set once `POST /merchants` succeeded -- the screen switches to its
  /// "Application submitted" state.
  final BusinessMerchant? registered;

  /// The web app's rule: a failed logo/cover upload never blocks the
  /// application; the user is told they can add it from their profile.
  final bool imageUploadFailed;

  MerchantRegistrationState copyWith({
    bool? isSubmitting,
    AppException? error,
    bool clearError = false,
    Map<String, List<String>>? fieldErrors,
    BusinessMerchant? registered,
    bool? imageUploadFailed,
  }) {
    return MerchantRegistrationState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      registered: registered ?? this.registered,
      imageUploadFailed: imageUploadFailed ?? this.imageUploadFailed,
    );
  }
}

/// Drives the two-step merchant registration (business details, then --
/// only when not already signed in -- account creation), mirroring the
/// merchant web app's wizard: the backend has no anonymous merchant
/// endpoint, so an account must exist before `POST /merchants`.
class MerchantRegistrationController extends Notifier<MerchantRegistrationState> {
  @override
  MerchantRegistrationState build() => const MerchantRegistrationState();

  /// [createAccount] is null when the caller is already authenticated.
  Future<void> submit({
    required MerchantRegistrationInput Function({String? logoUrl, String? coverImageUrl}) buildInput,
    XFile? logo,
    XFile? cover,
    ({String mobileNumber, String name, String password})? createAccount,
  }) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true, fieldErrors: const {});

    // 1. Account (only for a signed-out applicant).
    if (createAccount != null) {
      final auth = ref.read(authControllerProvider.notifier);
      await auth.register(createAccount.mobileNumber, createAccount.name, createAccount.password);
      final authState = ref.read(authControllerProvider);
      if (authState is! AuthAuthenticated) {
        final error = authState is AuthUnauthenticated ? authState.error : null;
        state = state.copyWith(
          isSubmitting: false,
          error: error ?? const UnknownAppException('Could not create your account.'),
          fieldErrors: error is ValidationAppException ? error.fieldErrors : const {},
        );
        return;
      }
    }

    // 2. Images -- best effort, never fatal.
    final repo = ref.read(businessMerchantRepositoryProvider);
    var uploadFailed = false;
    Future<String?> upload(XFile? file) async {
      if (file == null) return null;
      try {
        return await repo.uploadImage(file);
      } on AppException {
        uploadFailed = true;
        return null;
      }
    }

    final logoUrl = await upload(logo);
    final coverUrl = await upload(cover);

    // 3. The merchant itself.
    try {
      final merchant = await repo.register(buildInput(logoUrl: logoUrl, coverImageUrl: coverUrl));

      // The caller just became a Merchant Owner: refresh `/auth/me` so the
      // router and Business mode see the new profile, and land them in
      // Business mode straight away.
      await ref.read(authControllerProvider.notifier).refreshAccount();
      await ref.read(appModeControllerProvider.notifier).select(AppMode.business);

      state = state.copyWith(isSubmitting: false, registered: merchant, imageUploadFailed: uploadFailed);
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e,
        fieldErrors: e is ValidationAppException ? e.fieldErrors : const {},
        imageUploadFailed: uploadFailed,
      );
    }
  }
}

final merchantRegistrationControllerProvider =
    NotifierProvider.autoDispose<MerchantRegistrationController, MerchantRegistrationState>(MerchantRegistrationController.new);
