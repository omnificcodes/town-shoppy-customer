import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/merchants/data/models/merchant_business_hours.dart';

/// `business_hours` is schema-less JSON written by the web app's merchant
/// editor, so the parser has to cope with whatever is saved, and the
/// "open now" answer drives both Home's filter and the shop cards.
void main() {
  // 14 Sep 2026 is a Monday; each test picks a day relative to it.
  DateTime monday(int hour, [int minute = 0]) => DateTime(2026, 9, 14, hour, minute);
  DateTime tuesday(int hour, [int minute = 0]) => DateTime(2026, 9, 15, hour, minute);

  Map<String, Object> day(String open, String close, {bool closed = false}) => {
        'open': open,
        'close': close,
        'closed': closed,
      };

  test('the fixture dates are the weekdays the tests assume', () {
    expect(monday(12).weekday, DateTime.monday);
    expect(tuesday(12).weekday, DateTime.tuesday);
  });

  group('parsing', () {
    test('null, a non-map, an empty map and unreadable entries all mean "unknown"', () {
      expect(MerchantBusinessHours.tryParse(null), isNull);
      expect(MerchantBusinessHours.tryParse('9 to 5'), isNull);
      expect(MerchantBusinessHours.tryParse(<String, Object>{}), isNull);
      expect(MerchantBusinessHours.tryParse({'funday': day('09:00', '18:00')}), isNull);
      expect(MerchantBusinessHours.tryParse({'monday': day('nine', 'six')}), isNull);
    });

    test('accepts the editor\'s full weekday names and short forms alike', () {
      final full = MerchantBusinessHours.tryParse({'monday': day('09:00', '18:00')})!;
      final short = MerchantBusinessHours.tryParse({'Mon': day('09:00', '18:00')})!;

      expect(full.statusAt(monday(12)).isOpen, isTrue);
      expect(short.statusAt(monday(12)).isOpen, isTrue);
    });
  });

  group('open now', () {
    final hours = MerchantBusinessHours.tryParse({
      'monday': day('09:00', '18:00'),
      'tuesday': day('09:00', '18:00', closed: true),
    })!;

    test('open inside the day\'s hours, with the closing time', () {
      final status = hours.statusAt(monday(10, 30));
      expect(status.isOpen, isTrue);
      expect(status.label, 'Open until 6 PM');
    });

    test('closed before opening and from the closing minute on', () {
      expect(hours.statusAt(monday(8, 59)).isOpen, isFalse);
      expect(hours.statusAt(monday(18)).isOpen, isFalse);
      expect(hours.statusAt(monday(18)).label, 'Closed now');
    });

    test('a day marked closed is closed all day', () {
      expect(hours.statusAt(tuesday(12)).isOpen, isFalse);
    });

    test('a day missing from the map is closed, as the editor treats it', () {
      final wednesday = DateTime(2026, 9, 16, 12);
      expect(hours.statusAt(wednesday).isOpen, isFalse);
    });

    test('an overnight slot stays open past midnight into the next day', () {
      final late = MerchantBusinessHours.tryParse({'monday': day('18:00', '02:00')})!;

      expect(late.statusAt(monday(23)).isOpen, isTrue);
      expect(late.statusAt(tuesday(1, 30)).isOpen, isTrue);
      expect(late.statusAt(tuesday(1, 30)).label, 'Open until 2 AM');
      expect(late.statusAt(tuesday(2)).isOpen, isFalse);
      expect(late.statusAt(monday(17)).isOpen, isFalse);
    });

    test('the same open and close time means open 24 hours', () {
      final allDay = MerchantBusinessHours.tryParse({'monday': day('00:00', '00:00')})!;

      expect(allDay.statusAt(monday(3)).isOpen, isTrue);
      expect(allDay.statusAt(monday(3)).label, 'Open 24 hours');
    });
  });

  test('closing times read the way a shop sign does', () {
    expect(OpenStatus.formatClock(21 * 60), '9 PM');
    expect(OpenStatus.formatClock(21 * 60 + 30), '9:30 PM');
    expect(OpenStatus.formatClock(0), '12 AM');
    expect(OpenStatus.formatClock(12 * 60), '12 PM');
    expect(OpenStatus.formatClock(24 * 60), '12 AM');
  });
}
