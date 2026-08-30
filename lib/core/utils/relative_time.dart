/// Minimal relative-time formatter ("2 hours ago"). Deliberately hand-rolled
/// rather than adding a `timeago` dependency for one small piece of display
/// logic (section 56: check whether an equivalent already exists before
/// reaching for a package — here, plain `DateTime` math is enough).
String relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  final months = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dateTime.month - 1]} ${dateTime.day}';
}
