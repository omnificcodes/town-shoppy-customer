/// Magic review links (a plan feature, BR-20d): one QR code per shop that
/// asks a customer for a star rating first; 4 or 5 stars go on to the
/// shop's Google review page, lower ratings can leave a private note.
class ReviewLink {
  const ReviewLink({
    required this.id,
    required this.code,
    required this.publicUrl,
    required this.googleReviewUrl,
    required this.status,
    this.googleThreshold = 4,
  });

  factory ReviewLink.fromJson(Map<String, dynamic> json) => ReviewLink(
    id: json['id'] as int,
    code: json['code'] as String,
    publicUrl: json['public_url'] as String,
    googleReviewUrl: json['google_review_url'] as String,
    status: json['status'] as String? ?? 'active',
    googleThreshold: json['google_threshold'] as int? ?? 4,
  );

  final int id;
  final String code;

  /// What the QR code holds: the public rating page.
  final String publicUrl;
  final String googleReviewUrl;
  final String status;

  /// Ratings at or above this go on to Google.
  final int googleThreshold;

  bool get isActive => status == 'active';

  /// The address without its scheme, for printing under the QR.
  String get shortUrl => publicUrl.replaceFirst(RegExp(r'^https?://'), '');
}

class ReviewStats {
  const ReviewStats({
    required this.scans,
    required this.ratings,
    required this.averageRating,
    required this.sentToGoogle,
    required this.privateFeedback,
    required this.distribution,
  });

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    final raw = json['distribution'];
    final distribution = <int, int>{for (var s = 1; s <= 5; s++) s: 0};
    if (raw is Map) {
      raw.forEach((key, value) {
        final stars = int.tryParse('$key');
        if (stars != null && value is num) distribution[stars] = value.toInt();
      });
    }
    return ReviewStats(
      scans: json['scans'] as int? ?? 0,
      ratings: json['ratings'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      sentToGoogle: json['sent_to_google'] as int? ?? 0,
      privateFeedback: json['private_feedback'] as int? ?? 0,
      distribution: distribution,
    );
  }

  static const empty = ReviewStats(scans: 0, ratings: 0, averageRating: null, sentToGoogle: 0, privateFeedback: 0, distribution: {});

  final int scans;
  final int ratings;
  final double? averageRating;
  final int sentToGoogle;
  final int privateFeedback;

  /// Ratings per star count, 1 to 5.
  final Map<int, int> distribution;

  int countFor(int stars) => distribution[stars] ?? 0;
}

/// `GET /review-link`: whether the plan includes it, the link (null before
/// the owner sets it up) and its results.
class ReviewLinkOverview {
  const ReviewLinkOverview({required this.enabled, required this.link, required this.stats});

  factory ReviewLinkOverview.fromJson(Map<String, dynamic> json) => ReviewLinkOverview(
    enabled: json['enabled'] as bool? ?? false,
    link: json['link'] is Map ? ReviewLink.fromJson(Map<String, dynamic>.from(json['link'] as Map)) : null,
    stats: json['stats'] is Map ? ReviewStats.fromJson(Map<String, dynamic>.from(json['stats'] as Map)) : ReviewStats.empty,
  );

  final bool enabled;
  final ReviewLink? link;
  final ReviewStats stats;
}

/// One rating given through the link, with any private note.
class ReviewResponse {
  const ReviewResponse({
    required this.id,
    required this.rating,
    required this.sentToGoogle,
    required this.createdAt,
    this.feedback,
    this.customerName,
    this.contact,
  });

  factory ReviewResponse.fromJson(Map<String, dynamic> json) => ReviewResponse(
    id: json['id'] as int,
    rating: json['rating'] as int,
    sentToGoogle: json['sent_to_google'] as bool? ?? false,
    feedback: json['feedback'] as String?,
    customerName: json['customer_name'] as String?,
    contact: json['contact'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );

  final int id;
  final int rating;
  final bool sentToGoogle;
  final String? feedback;
  final String? customerName;
  final String? contact;
  final DateTime createdAt;
}
