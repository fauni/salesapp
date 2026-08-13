// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  id: (json['id'] as num).toInt(),
  docNum: (json['docNum'] as num).toInt(),
  customerCode: json['customerCode'] as String,
  customerName: json['customerName'] as String?,
  docDate: json['docDate'] == null
      ? null
      : DateTime.parse(json['docDate'] as String),
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  salesPersonCode: (json['salesPersonCode'] as num?)?.toInt(),
  salesPersonName: json['salesPersonName'] as String?,
  series: (json['series'] as num?)?.toInt(),
  comments: json['comments'] as String?,
  priceListNum: (json['priceListNum'] as num?)?.toInt(),
  priceListName: json['priceListName'] as String?,
  paymentTermsGroupCode: (json['paymentTermsGroupCode'] as num?)?.toInt(),
  paymentTermsGroupName: json['paymentTermsGroupName'] as String?,
  status: json['status'] as String,
  docTotal: (json['docTotal'] as num).toDouble(),
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'docNum': instance.docNum,
  'customerCode': instance.customerCode,
  'customerName': instance.customerName,
  'docDate': instance.docDate?.toIso8601String(),
  'dueDate': instance.dueDate?.toIso8601String(),
  'salesPersonCode': instance.salesPersonCode,
  'salesPersonName': instance.salesPersonName,
  'series': instance.series,
  'comments': instance.comments,
  'priceListNum': instance.priceListNum,
  'priceListName': instance.priceListName,
  'paymentTermsGroupCode': instance.paymentTermsGroupCode,
  'paymentTermsGroupName': instance.paymentTermsGroupName,
  'status': instance.status,
  'docTotal': instance.docTotal,
  'lines': instance.lines,
};

OrderLine _$OrderLineFromJson(Map<String, dynamic> json) => OrderLine(
  lineNum: (json['lineNum'] as num).toInt(),
  itemCode: json['itemCode'] as String,
  description: json['description'] as String?,
  quantity: (json['quantity'] as num).toDouble(),
  salesUnitOfMeasure: json['salesUnitOfMeasure'] as String?,
  unitPrice: (json['unitPrice'] as num?)?.toDouble(),
  lineTotal: (json['lineTotal'] as num).toDouble(),
  warehouseCode: json['warehouseCode'] as String?,
);

Map<String, dynamic> _$OrderLineToJson(OrderLine instance) => <String, dynamic>{
  'lineNum': instance.lineNum,
  'itemCode': instance.itemCode,
  'description': instance.description,
  'quantity': instance.quantity,
  'salesUnitOfMeasure': instance.salesUnitOfMeasure,
  'unitPrice': instance.unitPrice,
  'lineTotal': instance.lineTotal,
  'warehouseCode': instance.warehouseCode,
};
