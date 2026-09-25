import '../../../../core/utils/date_format.dart';
import '../../../purchases/data/models/purchase.dart';

/// What the Approve and Reject dialogs say, shared by the purchases list and
/// a purchase's own page so the two can never describe the same action
/// differently.
///
/// A bill carrying a Town Coin payment changes the one thing that matters
/// at the counter -- how much to collect -- so the dialog says that before
/// the tap, not after.
String approveTitle(Purchase purchase) =>
    purchase.coinPayment?.isWaiting == true ? 'Approve this payment?' : 'Approve this purchase?';

String approveMessage(Purchase purchase) {
  final coins = purchase.coinPayment;
  if (coins != null && coins.isWaiting) {
    return 'This deducts ${coins.coins} Town Coins from the customer and records the sale. '
        'Collect ${formatMoney(coins.amountPayable)} at the counter.';
  }
  return "Approving this purchase will record the transaction and issue the customer's applicable Town Coins "
      'and Lucky Draw coupons.';
}

const rejectMessage =
    'The customer will be notified. No Town Coins are deducted, and no coins or coupons are issued for a rejected purchase.';
