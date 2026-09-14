/// A merchant's weekly opening hours, as the web app's merchant editor
/// saves them into `business_hours`: a map of weekday to
/// `{"open": "09:00", "close": "18:00", "closed": false}`.
///
/// The backend stores that column as schema-less JSON, so parsing is
/// deliberately forgiving: weekday keys match on their first three letters
/// ("monday" and "mon" both work), and an unreadable entry is skipped rather
/// than failing the whole merchant. The editor treats a day missing from the
/// map as closed, and so does [statusAt].
class MerchantBusinessHours {
  const MerchantBusinessHours(this._days);

  /// Keyed by [DateTime.monday] through [DateTime.sunday].
  final Map<int, DayHours> _days;

  /// Null when nothing usable was saved, which means "hours unknown" --
  /// a different thing from "closed today".
  static MerchantBusinessHours? tryParse(Object? json) {
    if (json is! Map) return null;

    final days = <int, DayHours>{};
    json.forEach((key, value) {
      final weekday = _weekdayFor('$key');
      if (weekday == null || value is! Map) return;

      if (value['closed'] == true) {
        days[weekday] = const DayHours.closed();
        return;
      }

      final open = _minutesFor(value['open']);
      final close = _minutesFor(value['close']);
      if (open == null || close == null) return;

      days[weekday] = DayHours(openMinutes: open, closeMinutes: close);
    });

    return days.isEmpty ? null : MerchantBusinessHours(days);
  }

  OpenStatus statusAt(DateTime now) {
    final minutes = now.hour * 60 + now.minute;

    // A late slot that started yesterday and runs past midnight.
    final yesterday = _days[now.weekday == DateTime.monday ? DateTime.sunday : now.weekday - 1];
    if (yesterday != null && yesterday.isOvernight && minutes < yesterday.closeMinutes) {
      return OpenStatus.open(closesAt: yesterday.closeMinutes);
    }

    final today = _days[now.weekday];
    if (today == null || today.closed) return const OpenStatus.closed();
    if (today.isAllDay) return const OpenStatus.open();

    final isOpen = today.isOvernight
        ? minutes >= today.openMinutes
        : minutes >= today.openMinutes && minutes < today.closeMinutes;

    return isOpen ? OpenStatus.open(closesAt: today.closeMinutes) : const OpenStatus.closed();
  }

  static const _weekdayPrefixes = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };

  static int? _weekdayFor(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.length < 3) return null;
    return _weekdayPrefixes[normalized.substring(0, 3)];
  }

  static final _clock = RegExp(r'^(\d{1,2}):(\d{2})');

  static int? _minutesFor(Object? value) {
    if (value is! String) return null;
    final match = _clock.firstMatch(value.trim());
    if (match == null) return null;

    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    if (hours > 24 || minutes > 59) return null;

    return hours * 60 + minutes;
  }
}

class DayHours {
  const DayHours({required this.openMinutes, required this.closeMinutes}) : closed = false;

  const DayHours.closed()
      : openMinutes = 0,
        closeMinutes = 0,
        closed = true;

  /// Minutes after midnight.
  final int openMinutes;
  final int closeMinutes;
  final bool closed;

  /// The editor's way of saying "open 24 hours": the same open and close time.
  bool get isAllDay => !closed && openMinutes == closeMinutes;

  /// Closes after midnight, such as 18:00 to 02:00.
  bool get isOvernight => !closed && closeMinutes < openMinutes;
}

class OpenStatus {
  const OpenStatus.open({this.closesAt}) : isOpen = true;

  const OpenStatus.closed()
      : isOpen = false,
        closesAt = null;

  final bool isOpen;

  /// Minutes after midnight; null while open all day.
  final int? closesAt;

  String get label {
    if (!isOpen) return 'Closed now';
    final closing = closesAt;
    return closing == null ? 'Open 24 hours' : 'Open until ${formatClock(closing)}';
  }

  /// "9 PM", "9:30 PM", "12 AM" -- the way a shop sign reads.
  static String formatClock(int minutesAfterMidnight) {
    final hour = (minutesAfterMidnight ~/ 60) % 24;
    final minute = minutesAfterMidnight % 60;
    final period = hour < 12 ? 'AM' : 'PM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return minute == 0 ? '$hour12 $period' : '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}
