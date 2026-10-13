/// The merchant web app's convention for the free-form `business_hours`
/// JSON column: `{monday: {open: "09:00", close: "18:00", closed: false}, ...}`.
/// The backend validates only "is an array", so this is the one shared
/// shape both clients agree on -- mirror `MerchantBusinessHours` in
/// `town-shoppy-admin/src/types/api.ts`.
const merchantWeekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

String weekdayLabel(String weekday) => weekday.isEmpty ? weekday : '${weekday[0].toUpperCase()}${weekday.substring(1)}';

class DayHours {
  const DayHours({required this.open, required this.close, required this.closed});

  /// The web app's default for a day the merchant never set.
  static const unset = DayHours(open: '09:00', close: '18:00', closed: true);

  /// What a business starts with before it has set any hours: open 9 to 6.
  static const standard = DayHours(open: '09:00', close: '18:00', closed: false);

  factory DayHours.fromJson(Map<String, dynamic> json) {
    return DayHours(
      open: json['open'] as String? ?? unset.open,
      close: json['close'] as String? ?? unset.close,
      closed: json['closed'] as bool? ?? true,
    );
  }

  final String open; // "HH:mm"
  final String close; // "HH:mm"
  final bool closed;

  Map<String, dynamic> toJson() => {'open': open, 'close': close, 'closed': closed};

  DayHours copyWith({String? open, String? close, bool? closed}) {
    return DayHours(open: open ?? this.open, close: close ?? this.close, closed: closed ?? this.closed);
  }
}

class BusinessHours {
  const BusinessHours(this.days);

  /// Every day open 9 to 6 -- the starting point for a new business.
  static const standard = BusinessHours({
    'monday': DayHours.standard,
    'tuesday': DayHours.standard,
    'wednesday': DayHours.standard,
    'thursday': DayHours.standard,
    'friday': DayHours.standard,
    'saturday': DayHours.standard,
    'sunday': DayHours.standard,
  });

  factory BusinessHours.fromJson(Map<String, dynamic> json) {
    return BusinessHours({
      for (final day in merchantWeekdays)
        if (json[day] is Map) day: DayHours.fromJson(Map<String, dynamic>.from(json[day] as Map)),
    });
  }

  /// Only the days that were actually set. Read via [forDay] to get the
  /// web app's default for the rest.
  final Map<String, DayHours> days;

  DayHours forDay(String weekday) => days[weekday] ?? DayHours.unset;

  bool get isEmpty => days.isEmpty;

  /// Always the full 7-day map, the way the web app's edit form submits it.
  Map<String, dynamic> toJson() => {for (final day in merchantWeekdays) day: forDay(day).toJson()};
}
