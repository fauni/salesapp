// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_terms.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentTerms _$PaymentTermsFromJson(Map<String, dynamic> json) => PaymentTerms(
  code: (json['code'] as num).toInt(),
  name: json['name'] as String,
);

Map<String, dynamic> _$PaymentTermsToJson(PaymentTerms instance) =>
    <String, dynamic>{'code': instance.code, 'name': instance.name};
