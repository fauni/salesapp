import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';

/// Mirrors the backend `OrderDto`. `status` is display-only
/// (pending | approved | rejected) — SAP owns approval.
@JsonSerializable()
class Order {
  final int id;
  final int docNum;
  final String customerCode;
  final String? customerName;
  final DateTime? docDate;
  final DateTime? dueDate;
  final int? salesPersonCode;
  final String? salesPersonName;
  final int? series;
  final String? comments;
  final int? priceListNum;
  final String? priceListName;
  final int? paymentTermsGroupCode;
  final String? paymentTermsGroupName;
  final String status;

  // True once every line was closed in SAP (via "Cerrar pedido"). Status stays
  // "approved" — closing isn't an approval-procedure state.
  @JsonKey(defaultValue: false)
  final bool isClosed;

  final double docTotal;
  final List<OrderLine> lines;

  const Order({
    required this.id,
    required this.docNum,
    required this.customerCode,
    this.customerName,
    this.docDate,
    this.dueDate,
    this.salesPersonCode,
    this.salesPersonName,
    this.series,
    this.comments,
    this.priceListNum,
    this.priceListName,
    this.paymentTermsGroupCode,
    this.paymentTermsGroupName,
    required this.status,
    this.isClosed = false,
    required this.docTotal,
    this.lines = const [],
  });

  int get itemCount => lines.length;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);
}

@JsonSerializable()
class OrderLine {
  final int lineNum;
  final String itemCode;
  final String? description;
  final double quantity;
  final String? salesUnitOfMeasure;
  final double? unitPrice;
  final double lineTotal;
  final String? warehouseCode;
  final String? projectCode;
  final String? branchCode;

  const OrderLine({
    required this.lineNum,
    required this.itemCode,
    this.description,
    required this.quantity,
    this.salesUnitOfMeasure,
    this.unitPrice,
    required this.lineTotal,
    this.warehouseCode,
    this.projectCode,
    this.branchCode,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) =>
      _$OrderLineFromJson(json);
  Map<String, dynamic> toJson() => _$OrderLineToJson(this);
}
