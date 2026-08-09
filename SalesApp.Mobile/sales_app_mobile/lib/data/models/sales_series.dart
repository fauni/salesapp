import 'package:json_annotation/json_annotation.dart';

part 'sales_series.g.dart';

/// A SAP numbering series the salesperson is allowed to use (backend
/// `SalesSeriesDto`, from our own DB — not SAP's series catalog).
@JsonSerializable()
class SalesSeries {
  final int sapSeriesId;
  final String sapSeriesName;

  const SalesSeries({required this.sapSeriesId, required this.sapSeriesName});

  factory SalesSeries.fromJson(Map<String, dynamic> json) =>
      _$SalesSeriesFromJson(json);
  Map<String, dynamic> toJson() => _$SalesSeriesToJson(this);
}
