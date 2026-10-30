// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_warehouse.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagedWarehouse _$ManagedWarehouseFromJson(Map<String, dynamic> json) =>
    ManagedWarehouse(
      code: json['code'] as String,
      name: json['name'] as String,
      allowed: json['allowed'] as bool,
    );

Map<String, dynamic> _$ManagedWarehouseToJson(ManagedWarehouse instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'allowed': instance.allowed,
    };
