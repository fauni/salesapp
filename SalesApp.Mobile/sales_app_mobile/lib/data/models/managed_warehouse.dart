import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'managed_warehouse.g.dart';

/// A SAP warehouse as seen by the admin "Almacenes" screen (backend
/// `WarehouseDto`): whether sales orders may use it. The list is global — the
/// same for every user.
@JsonSerializable()
class ManagedWarehouse extends Equatable {
  final String code;
  final String name;
  final bool allowed;

  const ManagedWarehouse({
    required this.code,
    required this.name,
    required this.allowed,
  });

  factory ManagedWarehouse.fromJson(Map<String, dynamic> json) =>
      _$ManagedWarehouseFromJson(json);
  Map<String, dynamic> toJson() => _$ManagedWarehouseToJson(this);

  @override
  List<Object?> get props => [code, name, allowed];
}
