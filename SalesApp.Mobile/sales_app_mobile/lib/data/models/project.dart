import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'project.g.dart';

/// A SAP project (backend `ProjectDto`). [code] is the SAP project code;
/// [name] is for display.
@JsonSerializable()
class Project extends Equatable {
  final String code;
  final String name;

  const Project({required this.code, required this.name});

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  @override
  List<Object?> get props => [code, name];
}
