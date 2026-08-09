import 'package:json_annotation/json_annotation.dart';

part 'customer.g.dart';

/// Mirrors the backend `CustomerDto` (SAP Business Partner, CardType customer).
@JsonSerializable()
class Customer {
  final String code; // SAP CardCode
  final String name; // SAP CardName
  final String? phone;
  final String? cellular;
  final String? email;
  final String? federalTaxId;
  final String? currency;

  const Customer({
    required this.code,
    required this.name,
    this.phone,
    this.cellular,
    this.email,
    this.federalTaxId,
    this.currency,
  });

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerToJson(this);
}

/// Mirrors the backend `CustomerContactDto` (SAP ContactEmployees).
@JsonSerializable()
class CustomerContact {
  final int internalCode;
  final String name;
  final String? position;
  final String? phone;
  final String? mobilePhone;
  final String? email;
  final bool active;

  const CustomerContact({
    required this.internalCode,
    required this.name,
    this.position,
    this.phone,
    this.mobilePhone,
    this.email,
    this.active = true,
  });

  factory CustomerContact.fromJson(Map<String, dynamic> json) =>
      _$CustomerContactFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerContactToJson(this);
}
