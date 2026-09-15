import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/customer_profile_repository.dart';

class EditProfileState {
  const EditProfileState({this.isSubmitting = false, this.submitError, this.success = false});

  final bool isSubmitting;
  final AppException? submitError;

  /// One-shot flag the screen watches to pop itself -- reset is unnecessary
  /// since this controller is `autoDispose` and a fresh instance is built
  /// the next time the edit screen opens.
  final bool success;

  EditProfileState copyWith({
    bool? isSubmitting,
    AppException? submitError,
    bool clearSubmitError = false,
    bool? success,
  }) {
    return EditProfileState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      success: success ?? this.success,
    );
  }
}

/// A fresh instance per screen open (`autoDispose`) -- same convention as
/// [CustomerPurchaseRequestController].
class EditProfileController extends Notifier<EditProfileState> {
  @override
  EditProfileState build() => const EditProfileState();

  Future<void> submit({
    required String name,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    DateTime? anniversaryDate,
    bool clearAnniversaryDate = false,
    Map<String, String>? socialLinks,
    bool clearSocialLinks = false,
    String? profilePhotoUrl,
    bool clearProfilePhoto = false,
    String? coverImageUrl,
    bool clearCoverImage = false,
  }) async {
    if (state.isSubmitting) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      await ref
          .read(customerProfileRepositoryProvider)
          .update(
            name: name,
            dateOfBirth: dateOfBirth,
            clearDateOfBirth: clearDateOfBirth,
            anniversaryDate: anniversaryDate,
            clearAnniversaryDate: clearAnniversaryDate,
            socialLinks: socialLinks,
            clearSocialLinks: clearSocialLinks,
            profilePhotoUrl: profilePhotoUrl,
            clearProfilePhoto: clearProfilePhoto,
            coverImageUrl: coverImageUrl,
            clearCoverImage: clearCoverImage,
          );

      // So the greeting/profile screen reflect the edit immediately, not
      // just the next time the app happens to refetch `/auth/me`.
      await ref.read(authControllerProvider.notifier).refreshAccount();

      state = state.copyWith(isSubmitting: false, success: true);
    } on AppException catch (e) {
      state = state.copyWith(isSubmitting: false, submitError: e);
    }
  }
}

final editProfileControllerProvider = NotifierProvider.autoDispose<EditProfileController, EditProfileState>(
  EditProfileController.new,
);
