import '../../../shared/widgets/status_badge.dart';

/// Maps `OfferRedemptionStatus` (`pending`/`approved`/`rejected`) to a
/// display tone.
StatusTone offerRedemptionStatusTone(String status) => switch (status) {
      'approved' => StatusTone.success,
      'pending' => StatusTone.pending,
      'rejected' => StatusTone.error,
      _ => StatusTone.neutral,
    };

/// Customer-facing label for a raw `OfferRedemptionStatus` string.
/// `pending` is what the customer is waiting on (the merchant reviewing
/// their request), so it reads as that rather than the backend's word.
String offerRedemptionStatusLabel(String status) => switch (status) {
      'pending' => 'Awaiting merchant approval',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => status.isEmpty ? status : '${status[0].toUpperCase()}${status.substring(1)}',
    };
