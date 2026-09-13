/// Hand-rolled absolute date/time formatting ("12 Sep 2026, 7:45 PM") --
/// the same "no `intl` for one small formatter" reasoning as
/// `relative_time.dart`. Local time, since a merchant reads these at the
/// counter.
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String formatDateTime(DateTime d) {
  final local = d.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '${formatDate(local)}, $hour12:$minute $suffix';
}

/// "₹1,234.50" -- Indian-style grouping is deliberately NOT applied (the
/// rest of the app prints plain `toStringAsFixed(2)` amounts).
String formatMoney(double amount) => '₹${amount.toStringAsFixed(2)}';
