import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_envelope.dart';
import 'models/business_hours.dart';
import 'models/business_merchant.dart';
import 'models/merchant_registration_input.dart';

/// The merchant's own record, seen from the owner/staff side:
/// `GET /merchants/{id}` (returns `MerchantPrivateResource` because the
/// bearer token identifies an owner/staff of that merchant), `PATCH
/// /merchants/{id}` (Owner only -- `MerchantPolicy::update`), `POST
/// /merchants` (any signed-in account; creates a `pending` merchant plus an
/// active Owner profile for the caller), and the image upload both the
/// profile editor and the registration form feed into `logo_url` /
/// `cover_image_url`.
class BusinessMerchantRepository {
  BusinessMerchantRepository(this._dio);

  final Dio _dio;

  Future<BusinessMerchant> show(int merchantId) async {
    try {
      final response = await _dio.get('/merchants/$merchantId');
      return BusinessMerchant.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  Future<BusinessMerchant> register(MerchantRegistrationInput input) async {
    try {
      final response = await _dio.post('/merchants', data: input.toJson());
      return BusinessMerchant.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// PATCH semantics: every key present in [fields] is applied (a `null`
  /// value clears the column); absent keys are left untouched. The caller
  /// builds the map so the editor can send exactly what changed.
  Future<BusinessMerchant> update(int merchantId, Map<String, dynamic> fields) async {
    try {
      final response = await _dio.patch('/merchants/$merchantId', data: fields);
      return BusinessMerchant.fromJson(ApiEnvelope.data(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      ApiEnvelope.rethrowAsAppException(e);
    }
  }

  /// `POST /uploads/image` -- multipart field `image`, JPEG/PNG/WebP up to
  /// 5 MB, returns the public URL to store on the merchant. [XFile] rather
  /// than `dart:io File` so the same call works on web builds.
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
}

final businessMerchantRepositoryProvider = Provider<BusinessMerchantRepository>((ref) {
  return BusinessMerchantRepository(ref.watch(apiClientProvider).dio);
});

/// Builds the `PATCH /merchants/{id}` body for the profile editor. Kept
/// next to the repository so the "empty string means clear" rule lives in
/// one place -- the web app's edit sheet applies the same normalisation.
Map<String, dynamic> buildMerchantUpdateBody({
  required String name,
  required String ownerName,
  required String tagline,
  required int? categoryId,
  required String contactMobileNumber,
  required String contactEmail,
  required String description,
  required String gstNumber,
  required String? logoUrl,
  required String? coverImageUrl,
  required String websiteUrl,
  required String discountRate,
  required bool acceptsTownCoin,
  required Map<String, String> socialLinks,
  required BusinessHours businessHours,
}) {
  String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
  return {
    'name': name.trim(),
    'owner_name': ownerName.trim(),
    'tagline': orNull(tagline),
    if (categoryId != null) 'category_id': categoryId,
    'contact_mobile_number': orNull(contactMobileNumber),
    'contact_email': orNull(contactEmail),
    'description': orNull(description),
    'gst_number': orNull(gstNumber),
    'logo_url': logoUrl,
    'cover_image_url': coverImageUrl,
    'website_url': orNull(websiteUrl),
    'discount_rate': orNull(discountRate) == null ? null : double.tryParse(discountRate.trim()),
    'accepts_town_coin': acceptsTownCoin,
    'social_links': socialLinks.isEmpty ? null : socialLinks,
    'business_hours': businessHours.toJson(),
  };
}
