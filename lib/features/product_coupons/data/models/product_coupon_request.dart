/// Mirrors `App\Domain\Product\Http\Resources\ProductCouponRequestResource`
/// -- a customer asking a shop for one product's Lucky Draw coupons.
/// `customer` is only present in the shop's view, `merchant` only in the
/// customer's.
class ProductCouponRequest {
  const ProductCouponRequest({
    required this.id,
    required this.productId,
    required this.productName,
    required this.merchantId,
    required this.couponsRequested,
    required this.status,
    this.productImageUrl,
    this.merchantName,
    this.customerName,
    this.customerMobileNumber,
    this.couponsIssued,
    this.rejectionReason,
    this.createdAt,
    this.reviewedAt,
  });

  factory ProductCouponRequest.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    return ProductCouponRequest(
      id: json['id'] as int,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String? ?? 'Product',
      productImageUrl: json['product_image_url'] as String?,
      merchantId: json['merchant_id'] as int,
      merchantName: merchant?['name'] as String?,
      customerName: customer?['name'] as String?,
      customerMobileNumber: customer?['mobile_number'] as String?,
      couponsRequested: json['coupons_requested'] as int? ?? 0,
      couponsIssued: json['coupons_issued'] as int?,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'] as String) : null,
    );
  }

  final int id;

  /// Null once the shop has deleted the product; [productName] stays.
  final int? productId;
  final String productName;
  final String? productImageUrl;
  final int merchantId;
  final String? merchantName;
  final String? customerName;
  final String? customerMobileNumber;
  final int couponsRequested;
  final int? couponsIssued;

  /// `pending | approved | rejected`.
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
}
