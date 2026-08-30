/// A page of cursor-paginated results, mirroring the `{next_cursor,
/// prev_cursor}` meta shape used by every cursor-paginated backend
/// endpoint (`GET /audit-logs`, `GET /notifications`, `GET
/// /town-coins/transactions`).
class CursorPage<T> {
  const CursorPage({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
