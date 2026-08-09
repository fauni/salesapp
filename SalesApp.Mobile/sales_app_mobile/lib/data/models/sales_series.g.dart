// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_series.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SalesSeries _$SalesSeriesFromJson(Map<String, dynamic> json) => SalesSeries(
  sapSeriesId: (json['sapSeriesId'] as num).toInt(),
  sapSeriesName: json['sapSeriesName'] as String,
);

Map<String, dynamic> _$SalesSeriesToJson(SalesSeries instance) =>
    <String, dynamic>{
      'sapSeriesId': instance.sapSeriesId,
      'sapSeriesName': instance.sapSeriesName,
    };
