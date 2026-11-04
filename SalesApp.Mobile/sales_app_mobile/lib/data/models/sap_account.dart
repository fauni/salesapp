import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sap_account.g.dart';

/// A SAP user the backend logs in to the Service Layer with (backend
/// `SapAccountDto`), assigned to SalesApp users — several may share one.
/// Admin-only. The password is write-only: never returned by the API.
@JsonSerializable()
class SapAccount extends Equatable {
  final int id;
  final String name;
  final String username;
  final bool isActive;

  /// SalesApp users assigned to this account.
  final int userCount;

  const SapAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.isActive,
    required this.userCount,
  });

  factory SapAccount.fromJson(Map<String, dynamic> json) =>
      _$SapAccountFromJson(json);
  Map<String, dynamic> toJson() => _$SapAccountToJson(this);

  @override
  List<Object?> get props => [id, name, username, isActive, userCount];
}
