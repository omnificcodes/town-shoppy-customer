import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/lucky_draw/application/draws_list_controller.dart';
import 'package:customer/features/lucky_draw/application/my_vouchers_controller.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/lucky_draw/data/lucky_draw_repository.dart';
import 'package:customer/features/lucky_draw/data/models/draw.dart';
import 'package:customer/features/lucky_draw/data/models/draw_entry.dart';
import 'package:customer/features/lucky_draw/data/models/draw_winner.dart';
import 'package:customer/features/lucky_draw/data/models/prize.dart';
import 'package:customer/features/lucky_draw/data/models/voucher.dart';
import 'package:customer/features/lucky_draw/presentation/draw_detail_screen.dart';
import 'package:customer/features/lucky_draw/presentation/voucher_detail_screen.dart';
import 'package:customer/features/lucky_draw/presentation/voucher_tile.dart';

import '../../helpers/responsive_test_helper.dart';

/// The narrowest phone the audit mandates, on top of the standard sweep.
const _narrow = Size(320, 568);

const _prize = Prize(
  id: 1,
  sponsorMerchantName: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium',
  name: 'A twelve-month premium coffee subscription with weekly deliveries and a ceramic mug set',
  description: null,
  imageUrl: null,
  quantityTotal: 3,
  quantityRemaining: 1,
  status: 'active',
);

final _draw = Draw(
  id: 1,
  associationId: 1,
  cadence: 'monthly',
  scope: 'all',
  status: 'complete',
  poolLockedAt: DateTime(2026, 8, 30),
  executedAt: DateTime(2026, 9, 1),
  prizes: const [_prize],
  winnerCount: 2,
  createdAt: DateTime(2026, 8, 1),
);

final _winners = [
  DrawWinner(id: 1, drawId: 1, prize: _prize, winnerLabel: 'Priyankashree S.', status: 'selected', selectedAt: DateTime(2026, 9, 1)),
  DrawWinner(id: 2, drawId: 1, prize: null, winnerLabel: 'A customer', status: 'selected', selectedAt: DateTime(2026, 9, 1)),
];

/// The BR-44 entries list, with a long name and shop -- the page the detail
/// screen reads for its "All entries" section.
final _entries = DrawEntriesPage(
  page: OffsetPage(
    items: [
      const DrawEntry(
        id: 1,
        couponId: 10,
        entrantLabel: 'Priyankashree S.',
        couponCode: '****7G2K',
        shopName: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium',
        isWinner: true,
      ),
      const DrawEntry(id: 2, couponId: 11, entrantLabel: 'A customer', couponCode: '****9ZZ1', shopName: null, isWinner: false),
    ],
    currentPage: 1,
    lastPage: 1,
    total: 2,
  ),
  byShop: const [DrawShopEntries(id: 9, name: 'Corner Cafe', entries: 2)],
);

final _voucher = Voucher(
  id: 1,
  code: 'ABCD-EFGH-1234',
  prize: _prize,
  sponsorMerchantName: _prize.sponsorMerchantName,
  status: 'active',
  expiresAt: DateTime(2026, 10, 1),
  claimedAt: null,
  createdAt: DateTime(2026, 9, 1),
);

/// Wraps at 2x system text scale — the audit's upper bound.
Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  testWidgets('DrawDetailScreen renders long prize/winner names at 320px and 2x text without overflow', (tester) async {
    await forEachViewport(
      tester,
      sizes: [_narrow, ...kResponsiveViewportSizes],
      () => ProviderScope(
        overrides: [
          drawDetailProvider(1).overrideWith((ref) async => _draw),
          drawWinnersProvider(1).overrideWith((ref) async => _winners),
          drawEntriesPageProvider((1, 1)).overrideWith((ref) async => _entries),
        ],
        child: _app(const DrawDetailScreen(drawId: 1)),
      ),
      verify: (tester, size) async {
        expect(find.text('Monthly Draw'), findsOneWidget);
        // The hero and "Watch the draw" come first (BR-44); at 2x on a
        // 568px screen the explainer sits below the fold.
        await tester.dragUntilVisible(find.textContaining('Winners are drawn at random'), find.byType(ListView), const Offset(0, -200));
        expect(find.textContaining('Winners are drawn at random'), findsOneWidget);
        await tester.dragUntilVisible(find.text('Priyankashree S.'), find.byType(ListView), const Offset(0, -300));
        expect(find.text('Priyankashree S.'), findsOneWidget);
      },
    );
  });

  testWidgets('VoucherDetailScreen renders the claim deadline and QR at 320px and 2x text without overflow', (tester) async {
    await forEachViewport(
      tester,
      sizes: [_narrow, ...kResponsiveViewportSizes],
      () => ProviderScope(
        overrides: [
          voucherDetailProvider(1).overrideWith((ref) async => _voucher),
          voucherQrSecretProvider(1).overrideWith((ref) async => 'opaque-secret'),
        ],
        child: _app(const VoucherDetailScreen(voucherId: 1)),
      ),
      verify: (tester, size) async {
        expect(find.text('Ready to claim'), findsOneWidget);
        // At 2x the prize card alone can fill a 568px viewport; the deadline
        // and QR are below the fold, so scroll to them rather than assume.
        await tester.dragUntilVisible(find.textContaining('Claim by'), find.byType(ListView), const Offset(0, -200));
        expect(find.textContaining('Claim by'), findsOneWidget);
        await tester.dragUntilVisible(find.byType(QrImageView), find.byType(ListView), const Offset(0, -200));
        expect(
          find.byWidgetPredicate((w) => w is Semantics && w.properties.image == true && (w.properties.label ?? '').startsWith('Claim QR code')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('VoucherTile keeps its status badge beside a long prize name at 320px and 2x text', (tester) async {
    await forEachViewport(
      tester,
      sizes: [_narrow, ...kResponsiveViewportSizes],
      () => _app(Scaffold(body: VoucherTile(voucher: _voucher))),
      verify: (tester, size) async {
        expect(find.text('Ready to claim'), findsOneWidget);
      },
    );
  });
}
