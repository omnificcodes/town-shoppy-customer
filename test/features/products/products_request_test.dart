import 'dart:convert';
import 'dart:typed_data';

import 'package:customer/features/business/data/business_products_repository.dart';
import 'package:customer/features/products/data/products_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with an empty page and remembers what was asked.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({
        'data': <dynamic>[],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _RecordingAdapter adapter;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))..httpClientAdapter = adapter;
  });

  test('the customer catalog asks for the public listing, never a merchant-scoped one', () async {
    await ProductsRepository(dio).list();

    // `mine` is what narrows `/products` to the caller's own shop. The
    // Shopping tab must never send it, or a customer who also runs a
    // business would browse their own catalog instead of the town's.
    expect(adapter.last!.queryParameters.containsKey('mine'), isFalse);
    expect(adapter.last!.queryParameters.containsKey('merchant_id'), isFalse);
  });

  test('the customer catalog still scopes to one shop when asked, without the management flag', () async {
    await ProductsRepository(dio).list(merchantId: 7, filters: const {'search': 'cake'});

    expect(adapter.last!.queryParameters['merchant_id'], 7);
    expect(adapter.last!.queryParameters['search'], 'cake');
    expect(adapter.last!.queryParameters.containsKey('mine'), isFalse);
  });

  test('the merchant catalog asks for its own products, inactive ones included', () async {
    await BusinessProductsRepository(dio).list(merchantId: 7);

    expect(adapter.last!.queryParameters['mine'], 1);
    expect(adapter.last!.queryParameters['merchant_id'], 7);
  });
}
