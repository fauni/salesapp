import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_user.g.dart';

/// A SalesApp user (backend `UserDto`) — our own login, NOT a SAP user. Named
/// `AppUser` to avoid clashing with any implicit `User` type. Admin-only
/// management screen; see CLAUDE.md for the Users/Roles model.
@JsonSerializable()
class AppUser extends Equatable {
  final int id;
  final String username;
  final String? salesEmployeeCode;
  final bool isActive;
  final int roleId;
  final String roleName;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.username,
    this.salesEmployeeCode,
    required this.isActive,
    required this.roleId,
    required this.roleName,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  @override
  List<Object?> get props =>
      [id, username, salesEmployeeCode, isActive, roleId, roleName, createdAt];
}

/// The 3 roles seeded server-side (SalesApp.Core Role table) — fixed catalog,
/// no need for a picker/endpoint.
class AppRole {
  final int id;
  final String name;
  const AppRole(this.id, this.name);

  static const salesperson = AppRole(1, 'Salesperson');
  static const supervisor = AppRole(2, 'Supervisor');
  static const administrator = AppRole(3, 'Administrator');

  static const all = [salesperson, supervisor, administrator];
}
