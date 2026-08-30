/// A page of offset-paginated results, mirroring the `{current_page,
/// last_page, per_page, total}` meta shape used by `GET /purchases` and
/// `GET /redemptions` — distinct from [CursorPage], which mirrors the
/// `{next_cursor, prev_cursor}` shape used by `GET /notifications` and
/// `GET /town-coins/transactions`. The two backend endpoints this model
/// serves use classic page-number pagination, not cursors, so the two
/// pagination models are intentionally not unified.
class OffsetPage<T> {
  const OffsetPage({required this.items, required this.currentPage, required this.lastPage, required this.total});

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}
