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
  final double? price;
  final String? currency;
  final int? priceList;
  final List<ItemPrice> prices;
  final List<ItemWarehouseStock> warehouses;

  const Item({
    required this.code,
    required this.name,
    this.groupCode,
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
  final double inStock;
  final double committed;
  final double ordered;
  final double available;

  const ItemWarehouseStock({
    required this.warehouseCode,
    this.inStock = 0,
    this.committed = 0,
    this.ordered = 0,
    this.available = 0,
  });

  factory ItemWarehouseStock.fromJson(Map<String, dynamic> json) =>
      _$ItemWarehouseStockFromJson(json);
  Map<String, dynamic> toJson() => _$ItemWarehouseStockToJson(this);
}
