import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/profile/data/customer_profile_repository.dart';
import 'package:customer/features/profile/presentation/edit_profile_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/responsive_test_helper.dart';

final _account = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: const ['customer'],
  customerProfile: CustomerProfile(
    id: 7,
    name: 'Ammu Krishnan',
    dateOfBirth: null,
    anniversaryDate: null,
    socialLinks: const {'instagram': 'https://instagram.com/ammu'},
    referralCode: 'AMMU01',
    status: 'active',
    profilePhotoUrl: 'https://cdn.example.com/photo.jpg',
    coverImageUrl: null,
  ),
  merchantOwnerProfiles: const [],
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(_account);

  @override
  Future<void> refreshAccount() async {}
}

/// Records exactly what Save sends; never touches the network.
class _FakeCustomerProfileRepository extends CustomerProfileRepository {
  _FakeCustomerProfileRepository() : super(Dio());

  final calls = <Map<String, Object?>>[];

  @override
  Future<CustomerProfile> update({
    String? name,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    DateTime? anniversaryDate,
    bool clearAnniversaryDate = false,
    Map<String, String>? socialLinks,
    bool clearSocialLinks = false,
    String? profilePhotoUrl,
    bool clearProfilePhoto = false,
    String? coverImageUrl,
    bool clearCoverImage = false,
  }) async {
    calls.add({
      'name': name,
      'socialLinks': socialLinks,
      'clearSocialLinks': clearSocialLinks,
      'profilePhotoUrl': profilePhotoUrl,
      'clearProfilePhoto': clearProfilePhoto,
      'coverImageUrl': coverImageUrl,
      'clearCoverImage': clearCoverImage,
    });
    return _account.customerProfile!;
  }
}

/// Edit profile sits one route above a placeholder, as in the app, so a
/// successful save has somewhere to pop back to.
Widget _wrap(_FakeCustomerProfileRepository repository) {
  final router = GoRouter(
    initialLocation: '/profile/edit',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(body: Text('Profile home')),
        routes: [GoRoute(path: 'edit', builder: (context, state) => const EditProfileScreen())],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      customerProfileRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  // A tap that misses must fail the test, never pass it vacuously.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('shows photo controls, name and dates, and no social links, at every viewport', (tester) async {
    await forEachViewport(
      tester,
      () => _wrap(_FakeCustomerProfileRepository()),
      verify: (tester, size) async {
        expect(find.text('Edit profile'), findsOneWidget);
        expect(find.text('Add cover'), findsOneWidget);
        expect(find.text('Change photo'), findsOneWidget);
        expect(find.text('Remove photo'), findsOneWidget);

        final list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.text('Save changes'), 200, scrollable: list);
        expect(find.text('Special dates'), findsOneWidget);
        expect(find.text('Social media links'), findsNothing);
        expect(find.text('YouTube'), findsNothing);
      },
    );
  });

  testWidgets('Save leaves saved social links untouched and clears a removed photo', (tester) async {
    final repository = _FakeCustomerProfileRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(find.text('Upload photo'), findsOneWidget);

    final save = find.text('Save changes');
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(1));
    final call = repository.calls.single;
    expect(call['name'], 'Ammu Krishnan');
    expect(call['socialLinks'], isNull);
    expect(call['clearSocialLinks'], isFalse);
    expect(call['profilePhotoUrl'], isNull);
    expect(call['clearProfilePhoto'], isTrue);
    expect(call['clearCoverImage'], isFalse);
    // A successful save returns to the profile.
    expect(find.text('Profile home'), findsOneWidget);
  });
}
