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

    public List<ItemWarehouseStockDto> Warehouses { get; set; } = new();
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
