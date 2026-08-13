import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'item_unit_of_measure.g.dart';

/// A sales unit-of-measure option for an item (backend `ItemUnitOfMeasureDto`).
/// Loaded on demand when the line-config sheet opens. [code] is what goes to the
/// order line as `salesUnitOfMeasure`; [name] is for display; [isDefault] marks
/// the item's default sales UoM (preselected in the dropdown).
@JsonSerializable()
class ItemUnitOfMeasure extends Equatable {
  final String code;
  final String name;
  final bool isDefault;

  const ItemUnitOfMeasure({
    required this.code,
    required this.name,
    this.isDefault = false,
  });

  factory ItemUnitOfMeasure.fromJson(Map<String, dynamic> json) =>
      _$ItemUnitOfMeasureFromJson(json);
  Map<String, dynamic> toJson() => _$ItemUnitOfMeasureToJson(this);

  @override
  List<Object?> get props => [code, name, isDefault];
}
