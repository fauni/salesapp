using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;
using SalesApp.Infrastructure.Catalog;

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
    private readonly IWarehouseCatalog _warehouseCatalog;
    private readonly IAllowedWarehouses _allowedWarehouses;

    // Nested collections (ItemPrices / ItemWarehouseInfoCollection) must be in the
    // $select so SAP returns them inline — that's how we get price and stock.
    // InventoryWeight/InventoryUOM drive "sell by liters" (see ItemDto.LitersPerUnit).
    private const string ItemSelect =
        "ItemCode,ItemName,ItemsGroupCode,InventoryWeight,InventoryUOM,"
        + "ItemPrices,ItemWarehouseInfoCollection";

    // SAP Service Layer caps results per page (default 20) unless the caller sends
    // a Prefer: odata.maxpagesize header, which SapClient doesn't do today. Clamp
    // to that cap so $top never silently returns fewer rows than TotalCount implies.
    private const int MaxPageSize = 20;

    public ItemsController(
        ISapServiceLayerClient sapClient,
        IWarehouseCatalog warehouseCatalog,
        IAllowedWarehouses allowedWarehouses)
    {
        _sapClient = sapClient;
        _warehouseCatalog = warehouseCatalog;
        _allowedWarehouses = allowedWarehouses;
    }

    // GET /api/items?search=&category=&priceList=&inStockOnly=&page=&pageSize=
    [HttpGet]
    public async Task<ActionResult<PagedResult<ItemDto>>> Search(
        [FromQuery] string? search,
        [FromQuery] int? category,
        [FromQuery] int? priceList,
        [FromQuery] bool inStockOnly = false,
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

        // Stock filter: QuantityOnStock is a scalar Item field (total on-hand),
        // so OData can filter/paginate on it. This is NOT "available" (which
        // subtracts Committed per warehouse and can't be filtered server-side).
        if (inStockOnly)
            filters.Add("QuantityOnStock gt 0");

        var query = $"Items?$select={ItemSelect}&$orderby=ItemName"
                  + $"&$skip={(page - 1) * pageSize}&$top={pageSize}"
                  + "&$inlinecount=allpages";

        if (filters.Count > 0)
            query += $"&$filter={Uri.EscapeDataString(string.Join(" and ", filters))}";

        var json = await _sapClient.GetAsync(query, ct);
        // Cached in memory (one SAP read every few hours), not per item.
        var warehouses = await _warehouseCatalog.GetAllAsync(ct);
        var allowed = await _allowedWarehouses.GetCodesAsync(ct);

        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var items = root.GetProperty("value")
            .EnumerateArray()
            .Select(e => MapItem(e, priceList, warehouses, allowed))
            .ToList();

        return Ok(new PagedResult<ItemDto>
        {
            Items = items,
            Page = page,
            PageSize = pageSize,
            TotalCount = ReadInlineCount(root, items.Count)
        });
    }

    // GET /api/items/{code}/units-of-measure
    // Sales UoM options for one item, resolved on demand (the line-config sheet
    // calls this when it opens). Walks: Item -> UoM group -> group definitions
    // -> UnitOfMeasurements (codes/names). The item's default sales UoM is
    // flagged IsDefault. A "Manual" group (entry -1) yields a single row from
    // the item's own InventoryUOM.
    [HttpGet("{code}/units-of-measure")]
    public async Task<ActionResult<List<ItemUnitOfMeasureDto>>> UnitsOfMeasure(
        string code,
        CancellationToken ct = default)
    {
        var itemCode = code.Replace("'", "''");
        var itemJson = await _sapClient.GetAsync(
            $"Items('{Uri.EscapeDataString(itemCode)}')"
            + "?$select=UoMGroupEntry,DefaultSalesUoMEntry,InventoryUOM",
            ct);

        using var itemDoc = JsonDocument.Parse(itemJson);
        var itemEl = itemDoc.RootElement;

        var groupEntry = Int(itemEl, "UoMGroupEntry");
        var salesEntry = Int(itemEl, "DefaultSalesUoMEntry"); // AbsEntry of the default sales UoM
        var inventoryUom = Str(itemEl, "InventoryUOM");

        // No real UoM group (Manual = -1) → the item has only its inventory unit.
        if (groupEntry is null or (-1))
        {
            return Ok(new List<ItemUnitOfMeasureDto>
            {
                new()
                {
                    Code = inventoryUom ?? string.Empty,
                    Name = inventoryUom ?? string.Empty,
                    IsDefault = true,
                },
            });
        }

        // Group definitions carry the AlternateUoM entries that belong to the group.
        var groupJson = await _sapClient.GetAsync(
            $"UnitOfMeasurementGroups({groupEntry})"
            + "?$select=UoMGroupDefinitionCollection",
            ct);

        using var groupDoc = JsonDocument.Parse(groupJson);
        var altEntries = new List<int>();
        if (groupDoc.RootElement.TryGetProperty("UoMGroupDefinitionCollection", out var defs)
            && defs.ValueKind == JsonValueKind.Array)
        {
            foreach (var d in defs.EnumerateArray())
            {
                var alt = Int(d, "AlternateUoM");
                if (alt.HasValue && !altEntries.Contains(alt.Value))
                    altEntries.Add(alt.Value);
            }
        }

        if (altEntries.Count == 0)
            return Ok(new List<ItemUnitOfMeasureDto>());

        // Resolve all UoM codes/names in one call: UnitOfMeasurements filtered by
        // AbsEntry in the set of alternate entries.
        var inClause = string.Join(" or ", altEntries.Select(a => $"AbsEntry eq {a}"));
        var uomJson = await _sapClient.GetAsync(
            "UnitOfMeasurements?$select=AbsEntry,Code,Name"
            + $"&$filter={Uri.EscapeDataString($"({inClause})")}",
            ct);

        using var uomDoc = JsonDocument.Parse(uomJson);
        var result = new List<ItemUnitOfMeasureDto>();
        if (uomDoc.RootElement.TryGetProperty("value", out var uoms)
            && uoms.ValueKind == JsonValueKind.Array)
        {
            foreach (var u in uoms.EnumerateArray())
            {
                var absEntry = Int(u, "AbsEntry");
                result.Add(new ItemUnitOfMeasureDto
                {
                    Code = Str(u, "Code") ?? string.Empty,
                    Name = Str(u, "Name") ?? Str(u, "Code") ?? string.Empty,
                    IsDefault = salesEntry.HasValue && absEntry == salesEntry.Value,
                });
            }
        }

        // Ensure exactly one default: if none matched SalesUnitEntry, mark the first.
        if (result.Count > 0 && !result.Any(r => r.IsDefault))
            result[0].IsDefault = true;

        return Ok(result);
    }

    private static ItemDto MapItem(
        JsonElement e,
        int? priceList,
        IReadOnlyDictionary<string, WarehouseInfo> warehouseCatalog,
        IReadOnlySet<string> allowedWarehouses)
    {
        var dto = new ItemDto
        {
            Code = Str(e, "ItemCode") ?? string.Empty,
            Name = Str(e, "ItemName") ?? string.Empty,
            GroupCode = Int(e, "ItemsGroupCode"),
            InventoryUom = Str(e, "InventoryUOM")
        };

        // 0 means "not configured" in SAP — expose as null so the app falls
        // back to a plain editable quantity.
        var weight = Dec(e, "InventoryWeight");
        if (weight > 0) dto.LitersPerUnit = weight;

        // Every price-list row SAP has for this item, plus (if requested) the
        // single one resolved for the caller's price list — same pattern as
        // the Warehouses flattening below.
        if (e.TryGetProperty("ItemPrices", out var prices)
            && prices.ValueKind == JsonValueKind.Array)
        {
            foreach (var p in prices.EnumerateArray())
            {
                var listCode = Int(p, "PriceList");
                if (listCode is null) continue;

                var price = Dec(p, "Price") ?? 0m;
                var currency = Str(p, "Currency");

                dto.Prices.Add(new ItemPriceDto
                {
                    PriceList = listCode.Value,
                    Price = price,
                    Currency = currency
                });

                if (priceList.HasValue && listCode.Value == priceList.Value)
                {
                    dto.Price = price;
                    dto.Currency = currency;
                    dto.PriceList = priceList.Value;
                }
            }
        }

        // Stock per warehouse.
        if (e.TryGetProperty("ItemWarehouseInfoCollection", out var whs)
            && whs.ValueKind == JsonValueKind.Array)
        {
            foreach (var w in whs.EnumerateArray())
            {
                var code = Str(w, "WarehouseCode") ?? string.Empty;
                // Only the globally allowed warehouses (AllowedWarehouses
                // table) are offered; an empty list allows none.
                if (!allowedWarehouses.Contains(code)) continue;

                // Names come from the warehouse catalog. Inactive warehouses
                // can't take new orders, so they're left out of the choices; a
                // code missing from the catalog (e.g. names unavailable) stays.
                warehouseCatalog.TryGetValue(code, out var info);
                if (info?.Inactive == true) continue;

                var inStock = Dec(w, "InStock") ?? 0m;
                var committed = Dec(w, "Committed") ?? 0m;
                dto.Warehouses.Add(new ItemWarehouseStockDto
                {
                    WarehouseCode = code,
                    WarehouseName = info?.Name,
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
