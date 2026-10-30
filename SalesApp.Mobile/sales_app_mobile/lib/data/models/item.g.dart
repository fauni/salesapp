// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Item _$ItemFromJson(Map<String, dynamic> json) => Item(
  code: json['code'] as String,
  name: json['name'] as String,
  groupCode: (json['groupCode'] as num?)?.toInt(),
  litersPerUnit: (json['litersPerUnit'] as num?)?.toDouble(),
  inventoryUom: json['inventoryUom'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  currency: json['currency'] as String?,
  priceList: (json['priceList'] as num?)?.toInt(),
  prices:
      (json['prices'] as List<dynamic>?)
          ?.map((e) => ItemPrice.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  warehouses:
      (json['warehouses'] as List<dynamic>?)
          ?.map((e) => ItemWarehouseStock.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ItemToJson(Item instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
  'groupCode': instance.groupCode,
  'litersPerUnit': instance.litersPerUnit,
  'inventoryUom': instance.inventoryUom,
  'price': instance.price,
  'currency': instance.currency,
  'priceList': instance.priceList,
  'prices': instance.prices,
  'warehouses': instance.warehouses,
};

ItemPrice _$ItemPriceFromJson(Map<String, dynamic> json) => ItemPrice(
  priceList: (json['priceList'] as num).toInt(),
  price: (json['price'] as num).toDouble(),
  currency: json['currency'] as String?,
);

Map<String, dynamic> _$ItemPriceToJson(ItemPrice instance) => <String, dynamic>{
  'priceList': instance.priceList,
  'price': instance.price,
  'currency': instance.currency,
};

ItemWarehouseStock _$ItemWarehouseStockFromJson(Map<String, dynamic> json) =>
    ItemWarehouseStock(
      warehouseCode: json['warehouseCode'] as String,
      warehouseName: json['warehouseName'] as String?,
      inStock: (json['inStock'] as num?)?.toDouble() ?? 0,
      committed: (json['committed'] as num?)?.toDouble() ?? 0,
      ordered: (json['ordered'] as num?)?.toDouble() ?? 0,
      available: (json['available'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$ItemWarehouseStockToJson(ItemWarehouseStock instance) =>
    <String, dynamic>{
      'warehouseCode': instance.warehouseCode,
      'warehouseName': instance.warehouseName,
      'inStock': instance.inStock,
      'committed': instance.committed,
      'ordered': instance.ordered,
      'available': instance.available,
    };
