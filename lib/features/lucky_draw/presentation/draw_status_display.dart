import '../../../shared/widgets/status_badge.dart';

String drawCadenceTitle(String cadence) => switch (cadence) {
      'weekly' => 'Weekly Draw',
      'monthly' => 'Monthly Draw',
      'mega' => 'Mega Draw',
      _ => cadence,
    };

StatusTone voucherStatusTone(String status) => switch (status) {
      'active' => StatusTone.pending,
      'claimed' => StatusTone.success,
      'expired' => StatusTone.neutral,
      'void' => StatusTone.error,
      'replaced' => StatusTone.neutral,
      _ => StatusTone.neutral,
    };

String voucherStatusLabel(String status) => switch (status) {
      'active' => 'Ready to claim',
      'claimed' => 'Claimed',
      'expired' => 'Expired',
      'void' => 'Void',
      'replaced' => 'Replaced',
      _ => status,
    };
