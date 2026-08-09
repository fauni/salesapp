// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
  code: json['code'] as String,
  name: json['name'] as String,
  phone: json['phone'] as String?,
  cellular: json['cellular'] as String?,
  email: json['email'] as String?,
  federalTaxId: json['federalTaxId'] as String?,
  currency: json['currency'] as String?,
);

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
  'phone': instance.phone,
  'cellular': instance.cellular,
  'email': instance.email,
  'federalTaxId': instance.federalTaxId,
  'currency': instance.currency,
};

CustomerContact _$CustomerContactFromJson(Map<String, dynamic> json) =>
    CustomerContact(
      internalCode: (json['internalCode'] as num).toInt(),
      name: json['name'] as String,
      position: json['position'] as String?,
      phone: json['phone'] as String?,
      mobilePhone: json['mobilePhone'] as String?,
      email: json['email'] as String?,
      active: json['active'] as bool? ?? true,
    );

Map<String, dynamic> _$CustomerContactToJson(CustomerContact instance) =>
    <String, dynamic>{
      'internalCode': instance.internalCode,
      'name': instance.name,
      'position': instance.position,
      'phone': instance.phone,
      'mobilePhone': instance.mobilePhone,
      'email': instance.email,
      'active': instance.active,
    };
