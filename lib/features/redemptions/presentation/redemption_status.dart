import '../../../shared/widgets/status_badge.dart';

/// Maps `RedemptionStatus` (`initiated`/`verified`/`settled`/`expired`/
/// `cancelled` — see the backend enum) to a display tone.
StatusTone redemptionStatusTone(String status) => switch (status) {
      'settled' => StatusTone.success,
      'verified' => StatusTone.success,
      'initiated' => StatusTone.pending,
      'expired' => StatusTone.error,
      'cancelled' => StatusTone.error,
      _ => StatusTone.neutral,
    };
