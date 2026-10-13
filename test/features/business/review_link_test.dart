import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/application/review_link_providers.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/data/models/review_link.dart';
import 'package:customer/features/business/data/review_link_repository.dart';
import 'package:customer/features/business/presentation/review_link/business_review_link_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _link = {
  'id': 1,
  'code': 'abcd2345',
  'public_url': 'https://api.townshoppy.com/r/abcd2345',
  'google_review_url': 'https://g.page/r/Cabc/review',
  'status': 'active',
  'google_threshold': 4,
};

ReviewLinkOverview _overview({bool enabled = true, bool withLink = true}) => ReviewLinkOverview.fromJson({
  'enabled': enabled,
  'link': withLink ? _link : null,
  'stats': withLink
      ? {
          'scans': 42,
          'ratings': 10,
          'average_rating': 4.3,
          'sent_to_google': 8,
          'private_feedback': 1,
          'distribution': {'5': 6, '4': 2, '3': 1, '2': 1, '1': 0},
        }
      : null,
});

class _FakeRepository extends ReviewLinkRepository {
  _FakeRepository() : super(Dio());

  String? savedUrl;
  String? savedStatus;
  bool rejectUrl = false;

  @override
  Future<ReviewLinkOverview> save(int merchantId, {required String googleReviewUrl, String? status}) async {
    if (rejectUrl) {
      throw const ValidationAppException('Invalid', {
        'google_review_url': ['Paste the review link from your Google Business Profile.'],
      });
    }
    savedUrl = googleReviewUrl;
    savedStatus = status;
    return _overview();
  }

  @override
  Future<List<ReviewResponse>> responses(int merchantId, {bool privateOnly = false}) async => [
    ReviewResponse.fromJson({
      'id': 9,
      'rating': 2,
      'sent_to_google': false,
      'feedback': 'The billing queue was long',
      'customer_name': 'Asha',
      'contact': '9876543210',
      'created_at': DateTime.now().toIso8601String(),
    }),
  ];
}

Widget _wrap(_FakeRepository repository, ReviewLinkOverview overview, {bool isOwner = true}) {
  return ProviderScope(
    overrides: [
      reviewLinkRepositoryProvider.overrideWithValue(repository),
      reviewLinkProvider.overrideWith((ref) async => overview),
      myMerchantIdProvider.overrideWithValue(3),
      isBusinessOwnerProvider.overrideWithValue(isOwner),
      myMerchantProvider.overrideWith((ref) async => BusinessMerchant.fromJson({'id': 3, 'name': 'Kairaly Bakers', 'status': 'active'})),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const BusinessReviewLinkScreen()),
  );
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('before setup the owner sees how it works and must paste a Google review link', (tester) async {
    final repository = _FakeRepository();
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(repository, _overview(withLink: false)));
    await tester.pumpAndSettle();

    expect(find.text('Get more 5-star Google reviews'), findsOneWidget);
    expect(find.text('4★+ go to Google'), findsOneWidget);

    await tester.tap(find.text('Create my review QR'));
    await tester.pumpAndSettle();
    expect(find.text('Paste your Google review link.'), findsOneWidget);
    expect(repository.savedUrl, isNull);

    repository.rejectUrl = true;
    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.text('Create my review QR'));
    await tester.pumpAndSettle();
    expect(find.text('Paste the review link from your Google Business Profile.'), findsOneWidget);

    repository.rejectUrl = false;
    await tester.enterText(find.byType(TextField), 'https://g.page/r/Cabc/review');
    await tester.tap(find.text('Create my review QR'));
    await tester.pumpAndSettle();
    expect(repository.savedUrl, 'https://g.page/r/Cabc/review');
  });

  testWidgets('once set up it shows the QR poster, results and the private notes', (tester) async {
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _FakeRepository();
    await tester.pumpWidget(_wrap(repository, _overview()));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Kairaly Bakers'), findsOneWidget);
    expect(find.text('api.townshoppy.com/r/abcd2345'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('Review link is on'), findsOneWidget);
    expect(find.text('The billing queue was long'), findsOneWidget);
    expect(find.byTooltip('Call Asha'), findsOneWidget);

    // Pausing keeps the same Google link and sends status only.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repository.savedStatus, 'inactive');
    expect(repository.savedUrl, 'https://g.page/r/Cabc/review');
  });

  testWidgets('staff see the poster but no owner controls; a plan without it shows the upgrade', (tester) async {
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_FakeRepository(), _overview(), isOwner: false));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Google link'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(_FakeRepository(), _overview(enabled: false, withLink: false)));
    await tester.pumpAndSettle();
    expect(find.textContaining('not included in your current plan'), findsOneWidget);
    expect(find.text('See plans'), findsOneWidget);
  });
}
