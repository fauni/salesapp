using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;

namespace SalesApp.Api.Controllers;

// Items = SAP Items. We parse SAP's JSON and project our own DTOs (RF-18):
// price is resolved for the requested price list, and per-warehouse stock is
// flattened (RF-19/RF-21). SAP's raw JSON is never returned.
[ApiController]
[Route("api/items")]
[Authorize]
public class ItemsController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;

    // Nested collections (ItemPrices / ItemWarehouseInfoCollection) must be in the
    // $select so SAP returns them inline — that's how we get price and stock.
    private const string ItemSelect =
        "ItemCode,ItemName,ItemsGroupCode,ItemPrices,ItemWarehouseInfoCollection";

    // SAP Service Layer caps results per page (default 20) unless the caller sends
    // a Prefer: odata.maxpagesize header, which SapClient doesn't do today. Clamp
    // to that cap so $top never silently returns fewer rows than TotalCount implies.
    private const int MaxPageSize = 20;

    public ItemsController(ISapServiceLayerClient sapClient) => _sapClient = sapClient;

    // GET /api/items?search=&category=&priceList=&page=&pageSize=
    [HttpGet]
    public async Task<ActionResult<PagedResult<ItemDto>>> Search(
        [FromQuery] string? search,
        [FromQuery] int? category,
        [FromQuery] int? priceList,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = MaxPageSize,
        CancellationToken ct = default)
    {
        if (page < 1) page = 1;
        pageSize = Math.Clamp(pageSize, 1, MaxPageSize);

        var filters = new List<string>();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().Replace("'", "''"); // OData escapes ' by doubling
            filters.Add($"(contains(ItemName,'{s}') or contains(ItemCode,'{s}'))");
        }

        // category is the SAP ItemsGroupCode.
        if (category.HasValue)
            filters.Add($"ItemsGroupCode eq {category.Value}");

        var query = $"Items?$select={ItemSelect}&$orderby=ItemName"
                  + $"&$skip={(page - 1) * pageSize}&$top={pageSize}"
                  + "&$inlinecount=allpages";

        if (filters.Count > 0)
            query += $"&$filter={Uri.EscapeDataString(string.Join(" and ", filters))}";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var items = root.GetProperty("value")
            .EnumerateArray()
            .Select(e => MapItem(e, priceList))
            .ToList();

        return Ok(new PagedResult<ItemDto>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalCount = ReadInlineCount(root, items.Count)
        });
    }

    private static ItemDto MapItem(JsonElement e, int? priceList)
    {
        var dto = new ItemDto
        {
            Code = Str(e, "ItemCode") ?? string.Empty,
            Name = Str(e, "ItemName") ?? string.Empty,
            GroupCode = Int(e, "ItemsGroupCode")
        };

        // Price: pick the ItemPrices row matching the requested price list.
        if (priceList.HasValue
            && e.TryGetProperty("ItemPrices", out var prices)
            && prices.ValueKind == JsonValueKind.Array)
        {
            foreach (var p in prices.EnumerateArray())
            {
                if (Int(p, "PriceList") == priceList.Value)
                {
                    dto.Price = Dec(p, "Price");
                    dto.Currency = Str(p, "Currency");
                    dto.PriceList = priceList.Value;
                    break;
                }
            }
        }

        // Stock per warehouse.
        if (e.TryGetProperty("ItemWarehouseInfoCollection", out var whs)
            && whs.ValueKind == JsonValueKind.Array)
        {
            foreach (var w in whs.EnumerateArray())
            {
                var inStock = Dec(w, "InStock") ?? 0m;
                var committed = Dec(w, "Committed") ?? 0m;
                dto.Warehouses.Add(new ItemWarehouseStockDto
                {
                    WarehouseCode = Str(w, "WarehouseCode") ?? string.Empty,
                    InStock = inStock,
                    Committed = committed,
                    Ordered = Dec(w, "Ordered") ?? 0m,
                    Available = inStock - committed
                });
            }
        }

        return dto;
    }

    // SAP returns the total (with $inlinecount) as "odata.count", a string.
    // Fall back to the current page size if it's absent.
    private static int ReadInlineCount(JsonElement root, int fallback)
    {
        foreach (var name in new[] { "odata.count", "@odata.count" })
        {
            if (root.TryGetProperty(name, out var c))
            {
                if (c.ValueKind == JsonValueKind.String
                    && int.TryParse(c.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var n))
                    return n;
                if (c.ValueKind == JsonValueKind.Number && c.TryGetInt32(out var ni))
                    return ni;
            }
        }
        return fallback;
    }

    private static string? Str(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.String
            ? v.GetString()
            : null;

    private static int? Int(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.Number
            ? v.GetInt32()
            : null;

    private static decimal? Dec(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.Number
            ? v.GetDecimal()
            : null;
}
