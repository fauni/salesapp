// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  salesEmployeeCode: json['salesEmployeeCode'] as String?,
  sapAccountId: (json['sapAccountId'] as num?)?.toInt(),
  sapAccountName: json['sapAccountName'] as String?,
  isActive: json['isActive'] as bool,
  roleId: (json['roleId'] as num).toInt(),
  roleName: json['roleName'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'salesEmployeeCode': instance.salesEmployeeCode,
  'sapAccountId': instance.sapAccountId,
  'sapAccountName': instance.sapAccountName,
  'isActive': instance.isActive,
  'roleId': instance.roleId,
  'roleName': instance.roleName,
  'createdAt': instance.createdAt.toIso8601String(),
};
