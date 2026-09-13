import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../data/business_merchant_repository.dart';
import 'business_context.dart';

class EditBusinessProfileState {
  const EditBusinessProfileState({
    this.isSubmitting = false,
    this.isUploading = false,
    this.error,
    this.fieldErrors = const {},
    this.success = false,
  });

  final bool isSubmitting;

  /// A logo/cover upload in flight (uploads happen immediately on pick,
  /// like the web app's edit sheet, so the URL is ready by the time the
  /// form is saved).
  final bool isUploading;
  final AppException? error;
  final Map<String, List<String>> fieldErrors;
  final bool success;

  EditBusinessProfileState copyWith({
    bool? isSubmitting,
    bool? isUploading,
    AppException? error,
    bool clearError = false,
    Map<String, List<String>>? fieldErrors,
    bool? success,
  }) {
    return EditBusinessProfileState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      success: success ?? this.success,
    );
  }
}

class EditBusinessProfileController extends Notifier<EditBusinessProfileState> {
  @override
  EditBusinessProfileState build() => const EditBusinessProfileState();

  Future<String?> upload(XFile file) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final url = await ref.read(businessMerchantRepositoryProvider).uploadImage(file);
      state = state.copyWith(isUploading: false);
      return url;
    } on AppException catch (e) {
      state = state.copyWith(isUploading: false, error: e);
      return null;
    }
  }

  Future<void> submit(int merchantId, Map<String, dynamic> fields) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true, fieldErrors: const {});
    try {
      await ref.read(businessMerchantRepositoryProvider).update(merchantId, fields);
      ref.invalidate(myMerchantProvider);
      state = state.copyWith(isSubmitting: false, success: true);
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e,
        fieldErrors: e is ValidationAppException ? e.fieldErrors : const {},
      );
    }
  }
}

final editBusinessProfileControllerProvider =
    NotifierProvider.autoDispose<EditBusinessProfileController, EditBusinessProfileState>(EditBusinessProfileController.new);
