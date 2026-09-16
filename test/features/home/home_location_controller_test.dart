import 'package:customer/core/location/location_result.dart';
import 'package:customer/core/location/location_service.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/home/application/home_location_controller.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService extends LocationService {
  const _FakeLocationService(this.result);

  final LocationResult result;

  @override
  Future<LocationResult> getCurrentLocation() async => result;
}

NearbyMerchant _nearby({String? city, String? locality}) => NearbyMerchant.fromJson({
  'merchant': {'id': 7, 'name': 'Casiyo Home Appliances', 'accepts_town_coin': true},
  'branch': {'id': 3, 'address_line': '5 Market Rd', 'locality': ?locality, 'city': ?city, 'distance_km': 0.4},
  'distance_km': 0.4,
});

class _FakeMerchantsRepository extends MerchantsRepository {
  _FakeMerchantsRepository({this.items = const [], this.fails = false}) : super(Dio());

  final List<NearbyMerchant> items;
  final bool fails;
  double? askedRadiusKm;

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    double? radiusKm,
    int page = 1,
    int perPage = 50,
  }) async {
    askedRadiusKm = radiusKm;
    if (fails) throw const SocketExceptionStub();
    return OffsetPage(items: items, currentPage: 1, lastPage: 1, total: items.length);
  }
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

ProviderContainer _container({required LocationResult location, required _FakeMerchantsRepository merchants}) {
  final container = ProviderContainer(
    overrides: [
      locationServiceProvider.overrideWithValue(_FakeLocationService(location)),
      merchantsRepositoryProvider.overrideWithValue(merchants),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // The OS geocoder is a plugin, so it always fails here -- the same thing
  // that happens on every web build, which is what these cover.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('names the place from the nearest shop when the OS geocoder is unavailable', () async {
    final merchants = _FakeMerchantsRepository(items: [_nearby(city: 'Kakkanad')]);
    final container = _container(location: const LocationAvailable(10.0094, 76.3385), merchants: merchants);

    final state = await container.read(homeLocationControllerProvider.future);

    expect(state, isA<HomeLocationReady>());
    expect((state as HomeLocationReady).label, 'Kakkanad');
    expect(state.latitude, 10.0094);
    expect(merchants.askedRadiusKm, 25.0);
  });

  test('falls back to the branch locality when it has no city', () async {
    final container = _container(
      location: const LocationAvailable(10.0094, 76.3385),
      merchants: _FakeMerchantsRepository(items: [_nearby(locality: 'Edappally')]),
    );

    final state = await container.read(homeLocationControllerProvider.future);

    expect((state as HomeLocationReady).label, 'Edappally');
  });

  test('keeps the coordinates and a generic label when nothing can name the place', () async {
    final container = _container(
      location: const LocationAvailable(10.0094, 76.3385),
      merchants: _FakeMerchantsRepository(fails: true),
    );

    final state = await container.read(homeLocationControllerProvider.future);

    expect(state, isA<HomeLocationReady>());
    expect((state as HomeLocationReady).label, 'Current location');
    expect(state.longitude, 76.3385);
  });

  test('a denied permission reports why, so the header can explain it', () async {
    final container = _container(
      location: const LocationPermissionDeniedForever(),
      merchants: _FakeMerchantsRepository(),
    );

    final state = await container.read(homeLocationControllerProvider.future);

    expect(state, isA<HomeLocationUnavailable>());
    expect((state as HomeLocationUnavailable).reason, isA<LocationPermissionDeniedForever>());
  });
}
