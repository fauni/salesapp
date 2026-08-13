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

/// Mirrors the backend `CustomerDetailDto` (`GET /api/customers/{code}`).
///
/// Superset of [Customer]: adds the two commercial catalog fields the backend
/// resolves to human-readable names (price list / payment terms). Kept as a
/// standalone class — json_serializable doesn't cleanly serialize inherited
/// fields — but exposes [toCustomer] so the header UI can reuse [Customer].
/// `*Name` fields come pre-resolved by the backend and may be null when SAP has
/// no value or the code couldn't be resolved; `*Num`/`*Code` are the raw codes.
@JsonSerializable()
class CustomerDetail {
  final String code;
  final String name;
  final String? phone;
  final String? cellular;
  final String? email;
  final String? federalTaxId;
  final String? currency;
  final int? priceListNum;
  final String? priceListName;
  final int? paymentTermsGroupCode;
  final String? paymentTermsGroupName;

  const CustomerDetail({
    required this.code,
    required this.name,
    this.phone,
    this.cellular,
    this.email,
    this.federalTaxId,
    this.currency,
    this.priceListNum,
    this.priceListName,
    this.paymentTermsGroupCode,
    this.paymentTermsGroupName,
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) =>
      _$CustomerDetailFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerDetailToJson(this);

  Customer toCustomer() => Customer(
        code: code,
        name: name,
        phone: phone,
        cellular: cellular,
        email: email,
        federalTaxId: federalTaxId,
        currency: currency,
      );
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
