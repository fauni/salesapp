import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat('#,##0.00');
final NumberFormat _qty = NumberFormat('#,##0.###');
final DateFormat _date = DateFormat('dd/MM/yyyy');

/// Shared display formatters so cards/screens render numbers and dates
/// consistently.
String formatMoney(num value) => _money.format(value);

/// Display label for a SAP currency code ("BS" -> "Bs.", others as-is).
String currencyLabel(String code) => code == 'BS' ? 'Bs.' : code;

/// Quantities: trims trailing zeros (12 not 12.000, 1.5 stays 1.5).
String formatQty(num value) => _qty.format(value);

/// Stock quantity with its inventory UoM when known, plus its liters for
/// items sold by liters: "358", "358 BIDON" or "358 BIDON · 3,580 L".
/// See Item.litersFor.
String formatStock(num units, {String? uom, double? liters}) {
  final unit = uom?.trim() ?? '';
  final base = unit.isEmpty ? formatQty(units) : '${formatQty(units)} $unit';
  return liters == null ? base : '$base · ${formatQty(liters)} L';
}

String formatDate(DateTime? value) => value != null ? _date.format(value) : '-';
