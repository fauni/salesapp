part of 'cart_bloc.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object?> get props => [];
}

/// Sets the customer for the order being built (once, from the client picker).
class CartCustomerSet extends CartEvent {
  final Customer customer;
  const CartCustomerSet(this.customer);
  @override
  List<Object?> get props => [customer.code];
}

/// Adds a line, or replaces the existing one for the same item code.
class CartLineSaved extends CartEvent {
  final CartLine line;
  const CartLineSaved(this.line);
  @override
  List<Object?> get props => [line];
}

class CartLineRemoved extends CartEvent {
  final String itemCode;
  const CartLineRemoved(this.itemCode);
  @override
  List<Object?> get props => [itemCode];
}

class CartCleared extends CartEvent {
  const CartCleared();
}
