part of 'cart_bloc.dart';

class CartState extends Equatable {
  final Customer? customer;
  final List<CartLine> lines;

  const CartState({this.customer, this.lines = const []});

  int get count => lines.length;

  /// Sum of line subtotals. Note: without a price list, unit prices may be
  /// unset, so this can be 0 even with items in the cart.
  double get total => lines.fold(0, (sum, l) => sum + l.subtotal);

  bool get isEmpty => lines.isEmpty;

  CartLine? lineFor(String itemCode) {
    for (final l in lines) {
      if (l.itemCode == itemCode) return l;
    }
    return null;
  }

  CartState copyWith({Customer? customer, List<CartLine>? lines}) {
    return CartState(
      customer: customer ?? this.customer,
      lines: lines ?? this.lines,
    );
  }

  @override
  List<Object?> get props => [customer?.code, lines];
}
