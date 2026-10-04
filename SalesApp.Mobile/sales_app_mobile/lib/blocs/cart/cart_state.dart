part of 'cart_bloc.dart';

class CartState extends Equatable {
  final Customer? customer;
  final List<CartLine> lines;

  /// SAP project applied to the whole order (every line). Set from the
  /// summary's project picker; new lines saved afterwards inherit it too.
  final String? projectCode;

  /// SAP "Sucursal" (distribution rule) applied to the whole order (every
  /// line). Same pattern as [projectCode].
  final String? branchCode;

  const CartState({
    this.customer,
    this.lines = const [],
    this.projectCode,
    this.branchCode,
  });

  int get count => lines.length;

  /// Sum of line subtotals. Note: without a price list, unit prices may be
  /// unset, so this can be 0 even with items in the cart.
  double get total => lines.fold(0, (sum, l) => sum + l.subtotal);

  /// Sum of the liters entered on lines sold by liters (display only — not
  /// sent to SAP). Regular lines contribute nothing; 0 means "no liter lines".
  double get totalLiters =>
      lines.fold(0, (sum, l) => sum + (l.quantityInLiters ?? 0));

  bool get isEmpty => lines.isEmpty;

  CartLine? lineFor(String itemCode) {
    for (final l in lines) {
      if (l.itemCode == itemCode) return l;
    }
    return null;
  }

  CartState copyWith({
    Customer? customer,
    List<CartLine>? lines,
    String? projectCode,
    bool clearProjectCode = false,
    String? branchCode,
    bool clearBranchCode = false,
  }) {
    return CartState(
      customer: customer ?? this.customer,
      lines: lines ?? this.lines,
      projectCode:
          clearProjectCode ? null : (projectCode ?? this.projectCode),
      branchCode: clearBranchCode ? null : (branchCode ?? this.branchCode),
    );
  }

  @override
  List<Object?> get props =>
      [customer?.code, lines, projectCode, branchCode];
}
