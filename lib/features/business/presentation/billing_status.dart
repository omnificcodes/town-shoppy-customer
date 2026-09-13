import '../../../core/theme/app_colors.dart';

// Status vocabulary for Phase 4 -- same labels/tones as the merchant web
// app's `payment-status-badge.tsx`.

AppTone paymentStatusTone(String s) => switch (s) {
      'paid' => AppTone.success,
      'pending' => AppTone.pending,
      'failed' => AppTone.error,
      'refunded' => AppTone.info,
      _ => AppTone.neutral, // initiated, cancelled
    };

String paymentStatusLabel(String s) => switch (s) {
      'initiated' => 'Initiated',
      'pending' => 'Pending',
      'paid' => 'Paid',
      'failed' => 'Failed',
      'cancelled' => 'Cancelled',
      'refunded' => 'Refunded',
      _ => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).replaceAll('_', ' ')}',
    };

/// One line an owner can read under the status, so a non-final state is
/// never a mystery at the counter.
String paymentStatusHint(String s) => switch (s) {
      'initiated' => 'Checkout was started but not completed.',
      'pending' => 'The gateway is still confirming this payment.',
      'paid' => 'Payment received. Your package is active for this period.',
      'failed' => 'The gateway declined this payment. Nothing was charged.',
      'cancelled' => 'This checkout was cancelled before payment.',
      'refunded' => 'Town Shoppy refunded this payment.',
      _ => '',
    };

String paymentProviderLabel(String provider) => switch (provider) {
      'razorpay' => 'Razorpay',
      'cash' => 'Cash (recorded by Town Shoppy)',
      'fake' => 'Test gateway',
      '' => '—',
      _ => '${provider[0].toUpperCase()}${provider.substring(1)}',
    };
