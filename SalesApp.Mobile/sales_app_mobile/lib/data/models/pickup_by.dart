/// Who picks the order up. [code] is what the backend / SAP header UDF
/// `U_SL_Recoge` stores; [label] is shown in the UI.
enum PickupBy {
  customer('C', 'CLIENTE'),
  salesperson('V', 'VENDEDOR'),
  thirdPartyTransport('T', 'TRANSPORTE TERCERIZADO');

  final String code;
  final String label;
  const PickupBy(this.code, this.label);
}
