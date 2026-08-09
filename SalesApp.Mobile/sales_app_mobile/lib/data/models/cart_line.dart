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

  const CartLine({
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    this.salesUnitOfMeasure,
    this.unitPrice,
    this.warehouseCode,
  });

  double get subtotal => quantity * (unitPrice ?? 0);

  @override
  List<Object?> get props =>
      [itemCode, itemName, quantity, salesUnitOfMeasure, unitPrice, warehouseCode];
}
