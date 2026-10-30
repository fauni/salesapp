import 'package:json_annotation/json_annotation.dart';

part 'item.g.dart';

/// Mirrors the backend `ItemDto`. `price`/`currency`/`priceList` come back null
/// because the app does not send `priceList` (decision 2026-08-09) — the
/// catalog surfaces stock, not list price. `prices` always comes populated
/// with every SAP price-list row for the item, regardless of `priceList`;
/// the line-config sheet picks the row matching the cart customer's
/// `priceListNum` out of it.
@JsonSerializable()
class Item {
  final String code;
  final String name;
  final int? groupCode;

  /// Liters per inventory unit (SAP `InventoryWeight`). Non-null means the
  /// item is sold by liters: the rep enters liters and the quantity is derived
  /// (see [quantityForLiters]), always in [inventoryUom].
  final double? litersPerUnit;

  /// SAP `InventoryUOM` code — the fixed UoM for items sold by liters.
  final String? inventoryUom;

  final double? price;
  final String? currency;
  final int? priceList;
  final List<ItemPrice> prices;
  final List<ItemWarehouseStock> warehouses;

  const Item({
    required this.code,
    required this.name,
    this.groupCode,
    this.litersPerUnit,
    this.inventoryUom,
    this.price,
    this.currency,
    this.priceList,
    this.prices = const [],
    this.warehouses = const [],
  });

  /// The price row for [priceListNum], or null if the item has none for it.
  ItemPrice? priceFor(int? priceListNum) {
    if (priceListNum == null) return null;
    for (final p in prices) {
      if (p.priceList == priceListNum) return p;
    }
    return null;
  }

  bool get sellsByLiters => (litersPerUnit ?? 0) > 0;

  /// Units of inventory for [liters], or null unless [liters] is an exact,
  /// non-zero multiple of [litersPerUnit] (client rule: no fractional units).
  int? quantityForLiters(double liters) {
    final perUnit = litersPerUnit;
    if (perUnit == null || perUnit <= 0 || liters <= 0) return null;
    final units = liters / perUnit;
    final rounded = units.round();
    // Tolerance absorbs binary float noise (e.g. 0.3 / 0.1 = 2.9999999999999996).
    if (rounded < 1 || (units - rounded).abs() > 1e-6) return null;
    return rounded;
  }

  /// [units] of inventory expressed in liters (units × [litersPerUnit]) —
  /// the inverse of [quantityForLiters]. Null unless sold by liters. Display
  /// only: SAP's stock stays in inventory units.
  double? litersFor(double units) =>
      sellsByLiters ? units * litersPerUnit! : null;

  /// Sellable-now stock across all warehouses.
  double get totalAvailable =>
      warehouses.fold(0, (sum, w) => sum + w.available);

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
  Map<String, dynamic> toJson() => _$ItemToJson(this);
}

/// One price-list row for an item (SAP ItemPrices), mirrors `ItemPriceDto`.
@JsonSerializable()
class ItemPrice {
  final int priceList;
  final double price;
  final String? currency;

  const ItemPrice({
    required this.priceList,
    required this.price,
    this.currency,
  });

  factory ItemPrice.fromJson(Map<String, dynamic> json) =>
      _$ItemPriceFromJson(json);
  Map<String, dynamic> toJson() => _$ItemPriceToJson(this);
}

@JsonSerializable()
class ItemWarehouseStock {
  final String warehouseCode;

  /// SAP warehouse name, resolved by the backend. Null if it couldn't be
  /// resolved — use [displayName].
  final String? warehouseName;
  final double inStock;
  final double committed;
  final double ordered;
  final double available;

  const ItemWarehouseStock({
    required this.warehouseCode,
    this.warehouseName,
    this.inStock = 0,
    this.committed = 0,
    this.ordered = 0,
    this.available = 0,
  });

  /// Name for display, falling back to the code.
  String get displayName {
    final name = warehouseName?.trim() ?? '';
    return name.isEmpty ? warehouseCode : name;
  }

  /// Whether a name was resolved (so the code is worth showing beside it).
  bool get hasName => displayName != warehouseCode;

  factory ItemWarehouseStock.fromJson(Map<String, dynamic> json) =>
      _$ItemWarehouseStockFromJson(json);
  Map<String, dynamic> toJson() => _$ItemWarehouseStockToJson(this);
}
