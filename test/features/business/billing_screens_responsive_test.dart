import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/billing_controller.dart';
import 'package:customer/features/business/data/models/billing.dart';
import 'package:customer/features/business/presentation/billing/business_invoice_detail_screen.dart';
import 'package:customer/features/business/presentation/billing/business_invoices_screen.dart';
import 'package:customer/features/business/presentation/billing/business_payment_detail_screen.dart';
import 'package:customer/features/business/presentation/billing/business_payments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_test_helper.dart';

const _owner = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['merchant_owner'],
  customerProfile: null,
  merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
);

const _staff = Account(
  id: 2,
  mobileNumber: '+919990003002',
  status: 'active',
  isSuperAdmin: false,
  roles: ['merchant_staff'],
  customerProfile: null,
  merchantStaffProfiles: [MerchantProfileRef(id: 9, merchantId: 5, status: 'active')],
);

class _OwnerAuth extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_owner);
}

class _StaffAuth extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_staff);
}

final _refunded = MerchantPayment.fromJson({
  'id': 41,
  'payable_type': 'Subscription',
  'payable_id': 7,
  'invoice_id': 12,
  'provider': 'razorpay',
  'provider_order_id': 'order_AVeryLongGatewayOrderReference0001',
  'provider_payment_id': 'pay_AnEvenLongerGatewayPaymentReference000000001',
  'amount': 1234567.89,
  'currency': 'INR',
  'status': 'refunded',
  'refunded_amount': 1234567.89,
  'refunded_at': '2026-09-10T10:00:00+05:30',
  'created_at': '2026-09-01T10:00:00+05:30',
});

final _pending = MerchantPayment.fromJson({
  'id': 42,
  'payable_type': 'Subscription',
  'payable_id': 7,
  'provider': 'razorpay',
  'amount': 999,
  'currency': 'INR',
  'status': 'pending',
  'created_at': '2026-09-12T10:00:00+05:30',
});

final _invoice = MerchantInvoice.fromJson({
  'id': 12,
  'invoice_number': 'TS-2026-000012-WITH-A-LONG-SUFFIX',
  'payment_id': 41,
  'merchant': {'id': 5, 'name': 'A Merchant With A Really Quite Long Trading Name Pvt Ltd'},
  'amount': 846.61,
  'tax_amount': 152.39,
  'total_amount': 999,
  'currency': 'INR',
  'issued_at': '2026-09-01T10:00:05+05:30',
});

class _FakePayments extends BusinessPaymentsController {
  @override
  Future<BusinessPaymentsState> build() async => BusinessPaymentsState(
        items: [_refunded, _pending],
        currentPage: 1,
        lastPage: 1,
        totals: const PaymentTotals(payments: 2, successful: 0, failed: 0, refunded: 1),
      );
}

class _FakeInvoices extends BusinessInvoicesController {
  @override
  Future<BusinessInvoicesState> build() async => BusinessInvoicesState(items: [_invoice], currentPage: 1, lastPage: 1, total: 1);
}

Widget _app(Widget home, {bool owner = true, List<dynamic> overrides = const []}) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(owner ? _OwnerAuth.new : _StaffAuth.new),
        ...overrides,
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void main() {
  testWidgets('payments list renders totals, rows and the invoice hint at every viewport', (tester) async {
    await forEachViewport(
      tester,
      () => _app(const BusinessPaymentsScreen(), overrides: [businessPaymentsControllerProvider.overrideWith(_FakePayments.new)]),
      verify: (tester, size) async {
        expect(find.text('₹1234567.89'), findsOneWidget);
        expect(find.text('₹999.00'), findsOneWidget);
        expect(find.text('Refunded'), findsWidgets);
        expect(find.text('Pending'), findsWidgets);
        expect(find.text('Invoice'), findsOneWidget);
      },
    );
  });

  testWidgets('staff see the owner-only panel instead of the payments list', (tester) async {
    await tester.pumpWidget(_app(const BusinessPaymentsScreen(), owner: false, overrides: [businessPaymentsControllerProvider.overrideWith(_FakePayments.new)]));
    await tester.pumpAndSettle();
    expect(find.text('Owner only'), findsOneWidget);
    expect(find.text('₹999.00'), findsNothing);
  });

  testWidgets('payment detail lays out the hero, links and copyable references without overflow', (tester) async {
    await forEachViewport(
      tester,
      () => _app(const BusinessPaymentDetailScreen(paymentId: 41), overrides: [businessPaymentProvider(41).overrideWith((ref) async => _refunded)]),
      verify: (tester, size) async {
        expect(find.text('₹1234567.89'), findsOneWidget);
        expect(find.text('Invoice #12'), findsOneWidget);
        expect(find.text('Subscription #7'), findsOneWidget);
        await tester.dragUntilVisible(find.byTooltip('Copy Payment ID'), find.byType(ListView), const Offset(0, -200));
        expect(find.byTooltip('Copy Payment ID'), findsOneWidget);
      },
    );
  });

  testWidgets('invoices list renders the row and total at every viewport', (tester) async {
    await forEachViewport(
      tester,
      () => _app(const BusinessInvoicesScreen(), overrides: [businessInvoicesControllerProvider.overrideWith(_FakeInvoices.new)]),
      verify: (tester, size) async {
        expect(find.textContaining('TS-2026-000012'), findsOneWidget);
        expect(find.text('₹999.00'), findsOneWidget);
        expect(find.text('₹152.39'), findsOneWidget);
      },
    );
  });

  testWidgets('invoice detail shows the sheet with subtotal, tax and total', (tester) async {
    await forEachViewport(
      tester,
      () => _app(const BusinessInvoiceDetailScreen(invoiceId: 12), overrides: [businessInvoiceProvider(12).overrideWith((ref) async => _invoice)]),
      verify: (tester, size) async {
        expect(find.text('₹846.61'), findsOneWidget);
        expect(find.text('₹152.39'), findsOneWidget);
        expect(find.text('₹999.00'), findsOneWidget);
        expect(find.text('Payment #41'), findsOneWidget);
      },
    );
  });
}
