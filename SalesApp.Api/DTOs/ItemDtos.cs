namespace SalesApp.Api.DTOs;

// Public shape of a SAP Item. Never SAP's raw JSON — price is pre-resolved for
// the requested price list, and stock is flattened per warehouse (RF-18/19/21).
public class ItemDto
{
    public string Code { get; set; } = string.Empty;   // SAP ItemCode
    public string Name { get; set; } = string.Empty;   // SAP ItemName
    public int? GroupCode { get; set; }                 // SAP ItemsGroupCode (category)

    // Resolved from ItemPrices for the price list passed in the request. Null if
    // no price list was requested or the item has no row for that list.
    public decimal? Price { get; set; }
    public string? Currency { get; set; }
    public int? PriceList { get; set; }                 // which SAP price list the Price came from

    // Every price-list row SAP has for this item (ItemPrices), so callers who
    // need a specific list can pick it out without a second request.
    public List<ItemPriceDto> Prices { get; set; } = new();

    public List<ItemWarehouseStockDto> Warehouses { get; set; } = new();
}

// One price-list row for an item (SAP ItemPrices).
public class ItemPriceDto
{
    public int PriceList { get; set; }                 // SAP PriceList (matches PriceListDto.Code)
    public decimal Price { get; set; }                  // SAP Price
    public string? Currency { get; set; }                // SAP Currency
}

// Stock of one item in one warehouse (SAP ItemWarehouseInfoCollection) — RF-19.
public class ItemWarehouseStockDto
{
    public string WarehouseCode { get; set; } = string.Empty; // SAP WarehouseCode
    public decimal InStock { get; set; }                      // SAP InStock
    public decimal Committed { get; set; }                    // SAP Committed
    public decimal Ordered { get; set; }                      // SAP Ordered
    public decimal Available { get; set; }                    // InStock - Committed (sellable now)
}

// One sales unit-of-measure choice for an item, resolved on demand from the
// item's UoM group. Loaded when the line-config sheet opens, NOT in the catalog
// listing (would cost an extra SAP call per item).
public class ItemUnitOfMeasureDto
{
    public string Code { get; set; } = string.Empty;   // SAP UoM Code (goes to order line UoMCode)
    public string Name { get; set; } = string.Empty;   // SAP UoM Name (display)
    public bool IsDefault { get; set; }                 // true = item's default sales UoM
}
