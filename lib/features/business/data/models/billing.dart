/// Mirrors `PaymentResource` -- one subscription payment this merchant made
/// to Town Shoppy (`GET /payments`, Owner only). `metadata` and the
/// idempotency key are never exposed; the provider's order/payment ids are
/// the merchant's own receipt references and are shown for support.
class MerchantPayment {
  const MerchantPayment({
    required this.id,
    required this.merchantName,
    required this.payableType,
    required this.payableId,
    required this.invoiceId,
    required this.provider,
    required this.providerOrderId,
    required this.providerPaymentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.refundedAmount,
    required this.refundedAt,
    required this.createdAt,
  });

  factory MerchantPayment.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'];
    return MerchantPayment(
      id: json['id'] as int,
      merchantName: merchant is Map ? merchant['name'] as String? : null,
      payableType: json['payable_type'] as String? ?? '',
      payableId: json['payable_id'] as int?,
      invoiceId: json['invoice_id'] as int?,
      provider: json['provider'] as String? ?? '',
      providerOrderId: json['provider_order_id'] as String?,
      providerPaymentId: json['provider_payment_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? '',
      refundedAmount: (json['refunded_amount'] as num?)?.toDouble(),
      refundedAt: _date(json['refunded_at']),
      createdAt: _date(json['created_at']),
    );
  }

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;

  final int id;
  final String? merchantName;

  /// `Subscription` for every payment the platform issues today.
  final String payableType;
  final int? payableId;

  /// Set once the payment succeeded and an invoice was generated.
  final int? invoiceId;

  /// `razorpay`, `cash` (assigned offline by Town Shoppy staff) or the
  /// local `fake` gateway.
  final String provider;
  final String? providerOrderId;
  final String? providerPaymentId;
  final double amount;
  final String currency;

  /// `initiated | pending | paid | failed | cancelled | refunded`.
  final String status;
  final double? refundedAmount;
  final DateTime? refundedAt;
  final DateTime? createdAt;

  bool get isPaid => status == 'paid';
  bool get isRefunded => status == 'refunded';
  bool get isSettled => isPaid || isRefunded;
  bool get isForSubscription => payableType == 'Subscription';

  /// The reference a merchant would quote to support: the gateway's
  /// payment id, else its order id.
  String? get reference => providerPaymentId ?? providerOrderId;
}

/// `meta.totals` of `GET /payments` -- computed over the whole filtered
/// set *before* the status filter, so the strip stays stable while the
/// owner flips between status chips.
class PaymentTotals {
  const PaymentTotals({required this.payments, required this.successful, required this.failed, required this.refunded});

  factory PaymentTotals.fromJson(Map<String, dynamic>? json) {
    return PaymentTotals(
      payments: json?['payments'] as int? ?? 0,
      successful: json?['successful'] as int? ?? 0,
      failed: json?['failed'] as int? ?? 0,
      refunded: json?['refunded'] as int? ?? 0,
    );
  }

  static const empty = PaymentTotals(payments: 0, successful: 0, failed: 0, refunded: 0);

  final int payments;
  final int successful;
  final int failed;
  final int refunded;
}

/// Mirrors `InvoiceResource` -- the GST-aware billing record generated
/// once per successful payment. Immutable on the server; read-only here.
class MerchantInvoice {
  const MerchantInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.paymentId,
    required this.merchantName,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.currency,
    required this.issuedAt,
  });

  factory MerchantInvoice.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'];
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    final tax = (json['tax_amount'] as num?)?.toDouble() ?? 0;
    return MerchantInvoice(
      id: json['id'] as int,
      invoiceNumber: json['invoice_number'] as String? ?? '#${json['id']}',
      paymentId: json['payment_id'] as int?,
      merchantName: merchant is Map ? merchant['name'] as String? : null,
      amount: amount,
      taxAmount: tax,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? amount + tax,
      currency: json['currency'] as String? ?? 'INR',
      issuedAt: json['issued_at'] is String ? DateTime.tryParse(json['issued_at'] as String) : null,
    );
  }

  final int id;
  final String invoiceNumber;
  final int? paymentId;
  final String? merchantName;

  /// Pre-tax subtotal.
  final double amount;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final DateTime? issuedAt;
}

/// "₹1,234.00" for INR, "USD 12.00" otherwise -- the web `Money` component
/// formats by currency code; every payment today is INR so the rupee sign
/// is the path a merchant actually sees.
String formatCurrency(double amount, String currency) {
  if (currency.toUpperCase() == 'INR') return '₹${amount.toStringAsFixed(2)}';
  return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
}
