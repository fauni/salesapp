// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_person.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SalesPerson _$SalesPersonFromJson(Map<String, dynamic> json) => SalesPerson(
  code: (json['code'] as num).toInt(),
  name: json['name'] as String,
);

Map<String, dynamic> _$SalesPersonToJson(SalesPerson instance) =>
    <String, dynamic>{'code': instance.code, 'name': instance.name};
