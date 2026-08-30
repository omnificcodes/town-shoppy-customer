import '../../../shared/widgets/status_badge.dart';

/// Maps `PurchaseStatus` (`recorded`/`disputed`/`voided` — see the backend
/// enum) to a display tone. Shared between the Home "recent purchases"
/// preview and the full Purchases list/detail screens so the same status
/// always reads the same way everywhere in the app.
StatusTone purchaseStatusTone(String status) => switch (status) {
      'recorded' => StatusTone.success,
      'disputed' => StatusTone.pending,
      'voided' => StatusTone.error,
      _ => StatusTone.neutral,
    };
