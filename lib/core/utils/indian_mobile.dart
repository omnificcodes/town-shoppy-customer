/// One place that turns a stored mobile number into something dialable,
/// and the only place that ever writes India's country code.
///
/// Numbers reach this app in whatever shape a merchant typed them:
/// `9876543210`, `09876543210`, `+91 98765 43210`, `91-9876543210`. Every
/// caller used to strip the non-digits itself and then paste `91` in
/// front, which double-prefixed an already-prefixed number and sent
/// WhatsApp a `+919198765...` it rejects as invalid. So [dialableIndianMobile]
/// reduces any of those spellings to the bare ten-digit local number, and
/// [whatsappUri]/[telUri] add the code exactly once.
library;

/// The ten-digit local number, or null when [raw] is not a mobile number
/// this app can dial: only 10 digits (optionally written with a leading
/// `0` or a `91`/`+91` country code) starting 6-9, India's mobile range.
/// Spaces, dashes, brackets and a leading `+` are ignored; anything else
/// left over -- an extension, a landline, a wrong country -- returns null
/// rather than a number that would fail silently inside WhatsApp.
String? dialableIndianMobile(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final local = switch (digits.length) {
    10 => digits,
    11 when digits.startsWith('0') => digits.substring(1),
    12 when digits.startsWith('91') => digits.substring(2),
    // Both halves of the hybrid: "0 91 ..." and "91 0 ...", each written
    // by merchants who kept the trunk 0 alongside the country code.
    13 when digits.startsWith('091') || digits.startsWith('910') => digits.substring(3),
    _ => null,
  };
  if (local == null || !RegExp(r'^[6-9]').hasMatch(local)) return null;
  return local;
}

/// India's country code, without the `+`, as `wa.me` wants it.
const indianCountryCode = '91';

/// A `wa.me` deep link for [localNumber] -- which must be what
/// [dialableIndianMobile] returned, never a raw stored number, so the
/// country code is added exactly once. [text] is pre-filled into the chat.
Uri whatsappUri(String localNumber, {String? text}) {
  final query = text == null || text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}';
  return Uri.parse('https://wa.me/$indianCountryCode$localNumber$query');
}

/// A dialer link for [localNumber], from [dialableIndianMobile].
Uri telUri(String localNumber) => Uri.parse('tel:+$indianCountryCode$localNumber');
