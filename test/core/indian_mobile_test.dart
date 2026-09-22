import 'package:customer/core/utils/indian_mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading a stored number', () {
    test('accepts every spelling a merchant might have typed', () {
      expect(dialableIndianMobile('9876543210'), '9876543210');
      expect(dialableIndianMobile('+91 98765 43210'), '9876543210');
      expect(dialableIndianMobile('+919876543210'), '9876543210');
      expect(dialableIndianMobile('91-98765-43210'), '9876543210');
      expect(dialableIndianMobile('09876543210'), '9876543210');
      expect(dialableIndianMobile('+91 098765 43210'), '9876543210');
      expect(dialableIndianMobile('  98765 43210  '), '9876543210');
    });

    test('refuses what it cannot dial rather than guessing', () {
      expect(dialableIndianMobile(null), isNull);
      expect(dialableIndianMobile(''), isNull);
      expect(dialableIndianMobile('1234567890'), isNull, reason: 'Indian mobiles start 6-9');
      expect(dialableIndianMobile('98765 4321'), isNull, reason: 'too short');
      expect(dialableIndianMobile('+91 98765 43210 extension 00000'), isNull);
      expect(dialableIndianMobile('+1 415 555 0123'), isNull, reason: 'not an Indian number');
    });
  });

  group('the links it builds', () {
    test('write the country code exactly once, whatever was stored', () {
      for (final stored in ['9876543210', '+919876543210', '+91 98765 43210', '09876543210']) {
        final number = dialableIndianMobile(stored)!;

        expect(whatsappUri(number).toString(), 'https://wa.me/919876543210');
        expect(telUri(number).toString(), 'tel:+919876543210');
      }
    });

    test('a number stored with +91 never comes back doubled', () {
      // The reported bug: "+91" + a stored "+9198..." reached WhatsApp as
      // +919198..., which it rejects as not a valid phone number.
      final uri = whatsappUri(dialableIndianMobile('+91 98765 43210')!);

      expect(uri.toString(), isNot(contains('9191')));
      expect(uri.path, '/919876543210');
    });

    test('carries the order message as a query, leaving a bare link when there is none', () {
      final uri = whatsappUri('9876543210', text: 'Hi! 2 x Cookies — ₹298');

      expect(uri.queryParameters['text'], 'Hi! 2 x Cookies — ₹298');
      expect(uri.host, 'wa.me');
      expect(whatsappUri('9876543210').hasQuery, isFalse);
      expect(whatsappUri('9876543210', text: '').hasQuery, isFalse);
    });
  });
}
