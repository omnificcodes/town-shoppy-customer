import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import '../../auth/data/models/customer_profile.dart';

/// `PATCH /customer-profile` -- the authenticated customer's own profile,
/// no id in the URL (`CustomerProfileController`'s own docblock: "my own
/// by construction", same as the Customer QR endpoints). Every field is
/// optional; omit a key entirely to leave it unchanged, or send `null` to
/// clear a previously-set one.
class CustomerProfileRepository {
  CustomerProfileRepository(this._dio);

  final Dio _dio;

  Future<CustomerProfile> update({
    String? name,
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
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (dateOfBirth != null) 'date_of_birth': _dateOnly(dateOfBirth) else if (clearDateOfBirth) 'date_of_birth': null,
      if (anniversaryDate != null)
        'anniversary_date': _dateOnly(anniversaryDate)
      else if (clearAnniversaryDate)
        'anniversary_date': null,
      if (socialLinks != null) 'social_links': socialLinks else if (clearSocialLinks) 'social_links': null,
      if (profilePhotoUrl != null)
        'profile_photo_url': profilePhotoUrl
      else if (clearProfilePhoto)
        'profile_photo_url': null,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl else if (clearCoverImage) 'cover_image_url': null,
    };

    try {
      final response = await _dio.patch('/customer-profile', data: body);
      return CustomerProfile.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /uploads/image` -- multipart field `image`, JPEG/PNG/WebP up to
  /// 5 MB, returns the public URL to store as the profile photo or cover.
  /// [XFile] rather than `dart:io File` so the same call works on web.
  Future<String> uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final form = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: file.name.isEmpty ? 'image.jpg' : file.name),
      });
      final response = await _dio.post('/uploads/image', data: form);
      return (ApiEnvelope.data(response) as Map<String, dynamic>)['url'] as String;
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>((ref) {
  return CustomerProfileRepository(ref.watch(apiClientProvider).dio);
});
