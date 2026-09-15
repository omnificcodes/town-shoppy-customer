import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// The platforms Edit profile offers a dedicated field for. [key] is the
/// `social_links` map key the backend stores; [hosts] mirror
/// `UpdateCustomerProfileRequest::SOCIAL_PLATFORM_HOSTS` so the app rejects
/// exactly what the API would.
enum SocialPlatform {
  youtube(
    key: 'youtube',
    label: 'YouTube',
    icon: FontAwesomeIcons.youtube,
    brandColor: Color(0xFFFF0000),
    hint: 'https://youtube.com/@yourchannel',
    hosts: ['youtube.com', 'youtu.be'],
  ),
  facebook(
    key: 'facebook',
    label: 'Facebook',
    icon: FontAwesomeIcons.facebook,
    brandColor: Color(0xFF1877F2),
    hint: 'https://facebook.com/yourpage',
    hosts: ['facebook.com', 'fb.com'],
  ),
  instagram(
    key: 'instagram',
    label: 'Instagram',
    icon: FontAwesomeIcons.instagram,
    brandColor: Color(0xFFE1306C),
    hint: 'https://instagram.com/yourname',
    hosts: ['instagram.com'],
  ),
  linkedin(
    key: 'linkedin',
    label: 'LinkedIn',
    icon: FontAwesomeIcons.linkedin,
    brandColor: Color(0xFF0A66C2),
    hint: 'https://linkedin.com/in/yourname',
    hosts: ['linkedin.com'],
  );

  const SocialPlatform({
    required this.key,
    required this.label,
    required this.icon,
    required this.brandColor,
    required this.hint,
    required this.hosts,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color brandColor;
  final String hint;
  final List<String> hosts;

  static const keys = {'youtube', 'facebook', 'instagram', 'linkedin'};

  /// `null` when [value] is empty or a valid link for this platform,
  /// otherwise the message to show under the field.
  String? validate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return 'Enter a full link starting with https://';
    }
    final host = uri.host.toLowerCase();
    final matches = hosts.any((h) => host == h || host.endsWith('.$h'));
    return matches ? null : 'Enter a $label link';
  }
}
