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

/// Customer-facing label for a raw `RedemptionStatus` string. `initiated`
/// is what the customer is waiting on (the merchant verifying their code),
/// so it reads as that rather than as the backend's internal word.
String redemptionStatusLabel(String status) => switch (status) {
      'initiated' => 'Awaiting verification',
      'verified' => 'Verified',
      'settled' => 'Settled',
      'expired' => 'Expired',
      'cancelled' => 'Cancelled',
      _ => status.isEmpty ? status : '${status[0].toUpperCase()}${status.substring(1)}',
    };
