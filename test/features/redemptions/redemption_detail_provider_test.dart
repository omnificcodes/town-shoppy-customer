import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/redemptions/application/redemption_detail_provider.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:customer/features/redemptions/data/redemptions_repository.dart';

class FakeRedemptionsRepository implements RedemptionsRepository {
  FakeRedemptionsRepository({this.redemption, this.error});

  final Redemption? redemption;
  final AppException? error;

  @override
  Future<Redemption> show(int id) async {
    if (error != null) throw error!;
    return redemption!;
  }

  @override
  Future<OffsetPage<Redemption>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();
}

void main() {
  test('redemptionDetailProvider surfaces the loaded redemption', () async {
    final redemption = Redemption(
      id: 5,
      merchant: const RedemptionMerchantRef(id: 1, name: 'Sunrise Store'),
      branch: null,
      billAmount: 300,
      discountAmount: 50,
      remainingBillAmount: 250,
      coinsRequested: 100,
      coinsDebited: 100,
      status: 'settled',
      verificationMethod: 'qr',
      verifiedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
    final container = ProviderContainer(
      overrides: [redemptionsRepositoryProvider.overrideWithValue(FakeRedemptionsRepository(redemption: redemption))],
    );
    addTearDown(container.dispose);

    final result = await container.read(redemptionDetailProvider(5).future);

    expect(result.merchantName, 'Sunrise Store');
    expect(result.status, 'settled');
  });

  test('redemptionDetailProvider surfaces a 404 for an unavailable/deleted redemption', () async {
    final container = ProviderContainer(
      overrides: [redemptionsRepositoryProvider.overrideWithValue(FakeRedemptionsRepository(error: const NotFoundException()))],
    );
    addTearDown(container.dispose);

    // See the identical polling loop in `purchase_detail_provider_test.dart`
    // — Riverpod 3.3.2 keeps auto-retrying a failed build rather than
    // settling into a plain `AsyncError`.
    var state = container.read(redemptionDetailProvider(999));
    for (var i = 0; i < 50 && !state.hasError; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = container.read(redemptionDetailProvider(999));
    }

    expect(state.hasError, isTrue);
    expect(state.error, isA<NotFoundException>());
  });
}
