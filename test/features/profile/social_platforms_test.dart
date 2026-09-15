import 'package:customer/features/profile/presentation/social_platforms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty field is valid for every platform', () {
    for (final platform in SocialPlatform.values) {
      expect(platform.validate('   '), isNull);
    }
  });

  test('accepts the platform host and its subdomains', () {
    expect(SocialPlatform.youtube.validate('https://www.youtube.com/@town'), isNull);
    expect(SocialPlatform.youtube.validate('https://youtu.be/abc123'), isNull);
    expect(SocialPlatform.facebook.validate('https://m.facebook.com/townshoppy'), isNull);
    expect(SocialPlatform.facebook.validate('https://fb.com/townshoppy'), isNull);
    expect(SocialPlatform.instagram.validate('http://instagram.com/townshoppy'), isNull);
    expect(SocialPlatform.linkedin.validate('https://in.linkedin.com/in/townshoppy'), isNull);
  });

  test('rejects a link for another site, a lookalike host, or text without a scheme', () {
    expect(SocialPlatform.youtube.validate('https://vimeo.com/abc'), 'Enter a YouTube link');
    expect(SocialPlatform.facebook.validate('https://notfacebook.com/page'), 'Enter a Facebook link');
    expect(SocialPlatform.linkedin.validate('https://linkedin.com.evil.example/in/me'), 'Enter a LinkedIn link');
    expect(SocialPlatform.instagram.validate('instagram.com/me'), 'Enter a full link starting with https://');
  });

  test('platform keys match the social_links keys the API validates', () {
    expect(SocialPlatform.values.map((p) => p.key).toSet(), SocialPlatform.keys);
  });
}
