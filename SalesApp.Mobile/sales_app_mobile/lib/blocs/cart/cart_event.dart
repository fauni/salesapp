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

/// Sets (or clears, when null) the SAP project for the whole order. Reassigns
/// it to every line already in the cart, and new lines saved afterwards
/// inherit it automatically.
class CartProjectSet extends CartEvent {
  final String? projectCode;
  const CartProjectSet(this.projectCode);
  @override
  List<Object?> get props => [projectCode];
}

/// Sets (or clears, when null) the SAP "Sucursal" for the whole order. Same
/// behavior as [CartProjectSet]: reassigns every existing line and is
/// inherited by new lines saved afterwards.
class CartBranchSet extends CartEvent {
  final String? branchCode;
  const CartBranchSet(this.branchCode);
  @override
  List<Object?> get props => [branchCode];
}

/// Resets the cart and precharges it from an existing [Order] — used by
/// "Duplicar pedido" to open the summary with the source order's customer and
/// lines already loaded, ready to edit before creating a NEW order.
class CartInitializedFromOrder extends CartEvent {
  final Order order;
  const CartInitializedFromOrder(this.order);
  @override
  List<Object?> get props => [order.id];
}
