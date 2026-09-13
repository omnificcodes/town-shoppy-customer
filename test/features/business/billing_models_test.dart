import 'package:customer/features/business/application/billing_controller.dart';
import 'package:customer/features/business/application/list_range.dart';
import 'package:customer/features/business/data/models/billing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MerchantPayment', () {
    test('parses PaymentResource including the refund and invoice fields', () {
      final p = MerchantPayment.fromJson({
        'id': 41,
        'merchant': {'id': 1, 'name': 'Verification Store'},
        'payable_type': 'Subscription',
        'payable_id': 7,
        'invoice_id': 12,
        'provider': 'razorpay',
        'provider_order_id': 'order_ABC123',
        'provider_payment_id': 'pay_XYZ789',
        'amount': 999,
        'currency': 'INR',
        'status': 'refunded',
        'refunded_amount': 999.0,
        'refunded_at': '2026-09-10T10:00:00+05:30',
        'created_at': '2026-09-01T10:00:00+05:30',
      });
      expect(p.merchantName, 'Verification Store');
      expect(p.isForSubscription, isTrue);
      expect(p.invoiceId, 12);
      expect(p.reference, 'pay_XYZ789');
      expect(p.amount, 999);
      expect(p.isRefunded, isTrue);
      expect(p.isSettled, isTrue);
      expect(p.refundedAmount, 999);
      expect(p.refundedAt, isNotNull);
    });

    test('a cash payment with no gateway ids and no invoice still parses', () {
      final p = MerchantPayment.fromJson({'id': 2, 'payable_type': 'Subscription', 'payable_id': 3, 'provider': 'cash', 'amount': 499.5, 'currency': 'INR', 'status': 'paid'});
      expect(p.reference, isNull);
      expect(p.invoiceId, isNull);
      expect(p.isPaid, isTrue);
      expect(p.refundedAmount, isNull);
    });

    test('totals default to zero when meta.totals is absent', () {
      final t = PaymentTotals.fromJson(null);
      expect(t.payments, 0);
      expect(t.successful, 0);
      final u = PaymentTotals.fromJson({'payments': 5, 'successful': 4, 'failed': 1, 'refunded': 0});
      expect(u.payments, 5);
      expect(u.failed, 1);
    });
  });

  group('MerchantInvoice', () {
    test('parses InvoiceResource and falls back to amount + tax when total is missing', () {
      final i = MerchantInvoice.fromJson({
        'id': 12,
        'invoice_number': 'TS-2026-000012',
        'payment_id': 41,
        'merchant': {'id': 1, 'name': 'Verification Store'},
        'amount': 846.61,
        'tax_amount': 152.39,
        'currency': 'INR',
        'issued_at': '2026-09-01T10:00:05+05:30',
      });
      expect(i.invoiceNumber, 'TS-2026-000012');
      expect(i.paymentId, 41);
      expect(i.totalAmount, closeTo(999, 0.001));
      expect(i.issuedAt, isNotNull);
    });
  });

  group('formatCurrency', () {
    test('uses the rupee sign for INR and the code otherwise', () {
      expect(formatCurrency(999, 'INR'), '₹999.00');
      expect(formatCurrency(12.5, 'usd'), 'USD 12.50');
    });
  });

  group('DateWindow', () {
    test('a quick range sends only a from date', () {
      final w = const DateWindow().quick(ListRange.last7);
      expect(w.from, isNotNull);
      expect(w.to, isNull);
      expect(w.isActive, isTrue);
      expect(w.isCustom, isFalse);
      expect(w.label, 'Last 7 days');
    });

    test('a custom window sends both bounds as YYYY-MM-DD and labels itself', () {
      final w = const DateWindow().custom(DateTime(2026, 9, 1), DateTime(2026, 9, 13));
      expect(w.from, '2026-09-01');
      expect(w.to, '2026-09-13');
      expect(w.isCustom, isTrue);
      expect(w.label, '1 Sep 2026 – 13 Sep 2026');
    });

    test('all time is inactive and sends nothing', () {
      const w = DateWindow();
      expect(w.from, isNull);
      expect(w.to, isNull);
      expect(w.isActive, isFalse);
    });

    test('picking a quick range after a custom one drops the custom bounds', () {
      final w = const DateWindow().custom(DateTime(2026, 9, 1), DateTime(2026, 9, 13)).quick(ListRange.all);
      expect(w.isCustom, isFalse);
      expect(w.from, isNull);
    });
  });

  group('PaymentListFilters', () {
    test('reports whether anything narrows the list', () {
      expect(const PaymentListFilters().isFiltered, isFalse);
      expect(const PaymentListFilters(status: 'paid').isFiltered, isTrue);
      expect(const PaymentListFilters(search: 'pay_').isFiltered, isTrue);
      expect(const PaymentListFilters().apiStatus, isNull);
      expect(const PaymentListFilters(status: 'failed').apiStatus, 'failed');
    });
  });
}
