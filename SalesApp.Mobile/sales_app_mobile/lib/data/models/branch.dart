import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'branch.g.dart';

/// A SAP "Sucursal" (backend `BranchDto`, from SAP DistributionRules). [code]
/// is the SAP FactorCode sent on the order line; [name] is for display.
@JsonSerializable()
class Branch extends Equatable {
  final String code;
  final String name;

  const Branch({required this.code, required this.name});

  factory Branch.fromJson(Map<String, dynamic> json) =>
      _$BranchFromJson(json);
  Map<String, dynamic> toJson() => _$BranchToJson(this);

  @override
  List<Object?> get props => [code, name];
}
