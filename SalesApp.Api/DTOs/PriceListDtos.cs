namespace SalesApp.Api.DTOs;

// A SAP price list (OPLN / PriceLists) — read live from SAP, not our DB.
public class PriceListDto
{
    public int Code { get; set; }                      // SAP PriceListNo
    public string Name { get; set; } = string.Empty;    // SAP PriceListName
    public string? Currency { get; set; }                // SAP Currency (blank = "as item default")
    public int? BasePriceList { get; set; }              // SAP BasePriceList (source list when this one derives from another)
    public decimal? Factor { get; set; }                  // SAP Factor applied over BasePriceList
}
