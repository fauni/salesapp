// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sap_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SapAccount _$SapAccountFromJson(Map<String, dynamic> json) => SapAccount(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  username: json['username'] as String,
  isActive: json['isActive'] as bool,
  userCount: (json['userCount'] as num).toInt(),
);

Map<String, dynamic> _$SapAccountToJson(SapAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'username': instance.username,
      'isActive': instance.isActive,
      'userCount': instance.userCount,
    };
