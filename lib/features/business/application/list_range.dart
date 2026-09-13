/// The date-range filter the merchant web app's Purchases and Redemptions
/// lists share: only a `from` bound is ever sent; `to` stays open.
enum ListRange {
  all('All time'),
  last7('Last 7 days'),
  last30('Last 30 days'),
  last90('Last 90 days'),
  thisYear('This year');

  const ListRange(this.label);

  final String label;

  /// `YYYY-MM-DD` for the API, or null for "all time".
  String? fromDate([DateTime? now]) {
    final today = now ?? DateTime.now();
    final DateTime? from = switch (this) {
      ListRange.all => null,
      ListRange.last7 => today.subtract(const Duration(days: 7)),
      ListRange.last30 => today.subtract(const Duration(days: 30)),
      ListRange.last90 => today.subtract(const Duration(days: 90)),
      ListRange.thisYear => DateTime(today.year, 1, 1),
    };
    if (from == null) return null;
    return apiDate(from);
  }
}

/// `YYYY-MM-DD` -- the only date shape the list filters accept.
String apiDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
