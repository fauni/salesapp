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

  /// SAP Draft rather than a real Order. Pending/rejected are always drafts;
  /// an approved draft was authorized in SAP but not yet turned into the
  /// sales order — see [canGenerate].
  @JsonKey(defaultValue: false)
  final bool isDraft;

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
    this.isDraft = false,
    required this.docTotal,
    this.lines = const [],
  });

  int get itemCount => lines.length;

  /// Authorized in SAP, still a draft: the rep can generate the real order.
  bool get canGenerate => isDraft && status == 'approved';

  /// Route to this order's detail. The query tells the backend whether to
  /// read SAP Drafts or Orders.
  String get detailPath =>
      '/orders/$id?status=$status${isDraft ? '&draft=true' : ''}';

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

  /// SAP line UDF `U_TF_CANTLT` — liters for items sold by liters.
  final double? quantityInLiters;
  final double? unitPrice;

  /// SAP line `Currency` — currency of [unitPrice].
  final String? currency;
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
    this.quantityInLiters,
    this.unitPrice,
    this.currency,
    required this.lineTotal,
    this.warehouseCode,
    this.projectCode,
    this.branchCode,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) =>
      _$OrderLineFromJson(json);
  Map<String, dynamic> toJson() => _$OrderLineToJson(this);
}
