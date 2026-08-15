import 'package:equatable/equatable.dart';

/// A draft order line held in memory while building a new order (100% online —
/// nothing persisted). Keyed by [itemCode]; saving the same item replaces it.
class CartLine extends Equatable {
  final String itemCode;
  final String itemName;
  final double quantity;

  /// Sales UoM only (no TFE UoM). Optional — SAP uses the item default if null.
  final String? salesUnitOfMeasure;

  /// Optional manual price. Without a price list, SAP resolves the price on
  /// submit when this is null.
  final double? unitPrice;

  final String? warehouseCode;

  /// SAP project this line is tagged with. Set from the order-wide project
  /// picker in the summary — applied to every line, not chosen per-item.
  final String? projectCode;

  /// SAP "Sucursal" (distribution rule) this line is tagged with. Same
  /// pattern as [projectCode]: set order-wide from the summary.
  final String? branchCode;

  const CartLine({
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    this.salesUnitOfMeasure,
    this.unitPrice,
    this.warehouseCode,
    this.projectCode,
    this.branchCode,
  });

  double get subtotal => quantity * (unitPrice ?? 0);

  CartLine copyWith({
    String? projectCode,
    bool keepProjectCode = false,
    String? branchCode,
    bool keepBranchCode = false,
  }) =>
      CartLine(
        itemCode: itemCode,
        itemName: itemName,
        quantity: quantity,
        salesUnitOfMeasure: salesUnitOfMeasure,
        unitPrice: unitPrice,
        warehouseCode: warehouseCode,
        projectCode: keepProjectCode ? this.projectCode : projectCode,
        branchCode: keepBranchCode ? this.branchCode : branchCode,
      );

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        quantity,
        salesUnitOfMeasure,
        unitPrice,
        warehouseCode,
        projectCode,
        branchCode
      ];
}
