// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_unit_of_measure.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ItemUnitOfMeasure _$ItemUnitOfMeasureFromJson(Map<String, dynamic> json) =>
    ItemUnitOfMeasure(
      code: json['code'] as String,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$ItemUnitOfMeasureToJson(ItemUnitOfMeasure instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'isDefault': instance.isDefault,
    };
