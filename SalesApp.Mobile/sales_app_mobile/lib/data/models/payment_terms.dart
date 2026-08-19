import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_terms.g.dart';

/// A SAP payment terms group (backend `PaymentTermsDto`). [code] is the SAP
/// GroupNumber sent on the order header; [name] is for display.
@JsonSerializable()
class PaymentTerms extends Equatable {
  final int code;
  final String name;

  const PaymentTerms({required this.code, required this.name});

  factory PaymentTerms.fromJson(Map<String, dynamic> json) =>
      _$PaymentTermsFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentTermsToJson(this);

  @override
  List<Object?> get props => [code, name];
}
