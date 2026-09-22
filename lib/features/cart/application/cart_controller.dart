import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../products/data/models/product.dart';
import '../../products/presentation/product_price.dart';

/// One product in the bag, with how many of it.
@immutable
class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get total => product.price * quantity;

  /// What this line saves against the MRP, or 0 when the product carries
  /// no discount.
  double get saved => (product.saving ?? 0) * quantity;

  CartLine copyWith({int? quantity}) => CartLine(product: product, quantity: quantity ?? this.quantity);
}

/// The bag.
///
/// It holds ONE merchant's products at a time, and that is a constraint of
/// the ordering channel rather than a UI simplification: checkout opens a
/// `wa.me` link to a single shop's own contact number (there is no server-
/// side order, cart or payment anywhere in this app), so a bag mixing two
/// shops could not be sent anywhere. Adding a product from another shop
/// offers to start a new bag instead.
///
/// It is in-memory only: closing the app empties it. Nothing about it
/// reaches the backend.
@immutable
class CartState {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  /// The shop every line belongs to -- null while the bag is empty.
  int? get merchantId => lines.isEmpty ? null : lines.first.product.merchantId;

  String get merchantName => lines.isEmpty ? '' : lines.first.product.merchantName;

  /// The number that checkout would message; null when the shop has not
  /// published one, in which case the bag cannot be ordered.
  String? get contactMobileNumber {
    if (lines.isEmpty) return null;
    final number = lines.first.product.merchantContactMobileNumber?.trim();
    return number == null || number.isEmpty ? null : number;
  }

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  double get total => lines.fold(0, (sum, line) => sum + line.total);

  double get saved => lines.fold(0, (sum, line) => sum + line.saved);

  int quantityOf(int productId) {
    for (final line in lines) {
      if (line.product.id == productId) return line.quantity;
    }
    return 0;
  }

  /// Whether [product] can join the bag as it stands, i.e. the bag is
  /// empty or already holds this same shop's products.
  bool accepts(Product product) => isEmpty || merchantId == product.merchantId;
}

class CartController extends Notifier<CartState> {
  static const maxQuantityPerLine = 99;

  @override
  CartState build() {
    // One account's bag must never survive into the next account's
    // session, the same rule every other per-customer cache here follows.
    ref.watch(sessionEpochProvider);
    return const CartState();
  }

  /// Adds one, or raises an existing line by one. Returns false and
  /// changes nothing when the product belongs to a different shop —
  /// the caller then asks whether to start a new bag.
  bool add(Product product) {
    if (!state.accepts(product)) return false;
    setQuantity(product, state.quantityOf(product.id) + 1);
    return true;
  }

  /// Empties the bag and puts [product] in it — the answer to "start a new
  /// bag with this shop's product?".
  void startNewBagWith(Product product) {
    state = CartState(lines: [CartLine(product: product, quantity: 1)]);
  }

  /// Sets one product's quantity; 0 or less removes the line.
  void setQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      state = CartState(lines: state.lines.where((line) => line.product.id != product.id).toList());
      return;
    }
    if (!state.accepts(product)) return;

    final capped = quantity > maxQuantityPerLine ? maxQuantityPerLine : quantity;
    final existing = state.lines.indexWhere((line) => line.product.id == product.id);

    if (existing == -1) {
      state = CartState(
        lines: [
          ...state.lines,
          CartLine(product: product, quantity: capped),
        ],
      );
      return;
    }

    final lines = [...state.lines];
    // Re-seat the product too: a newly fetched copy may carry a changed
    // price, and the bag should charge what the catalog now says.
    lines[existing] = CartLine(product: product, quantity: capped);
    state = CartState(lines: lines);
  }

  void clear() => state = const CartState();
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(CartController.new);

/// How many of one product are in the bag. Narrow on purpose: a card
/// rebuilds only when its own line changes, not on every bag change.
final cartQuantityProvider = Provider.family<int, int>((ref, productId) {
  return ref.watch(cartControllerProvider.select((cart) => cart.quantityOf(productId)));
});

/// The bag as a WhatsApp order, addressed to the one shop it belongs to.
/// Mirrors a single product's order message in tone, with a line per
/// product and what the whole bag comes to.
String buildCartOrderMessage(CartState cart) {
  final lines = <String>[
    "Hi! I'd like to order from ${cart.merchantName}:",
    '',
    for (final line in cart.lines) '${line.quantity} x ${line.product.name} — ${formatRupees(line.total)}',
    '',
    'Total: ${formatRupees(cart.total)}',
    if (cart.saved > 0) 'You save: ${formatRupees(cart.saved)}',
  ];
  return lines.join('\n');
}
