import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sales_person.g.dart';

/// A SAP salesperson (backend `SalesPersonDto`). [code] is the SAP
/// SalesEmployeeCode sent on the order line; [name] is for display.
@JsonSerializable()
class SalesPerson extends Equatable {
  final int code;
  final String name;

  const SalesPerson({required this.code, required this.name});

  factory SalesPerson.fromJson(Map<String, dynamic> json) =>
      _$SalesPersonFromJson(json);
  Map<String, dynamic> toJson() => _$SalesPersonToJson(this);

  @override
  List<Object?> get props => [code, name];
}
