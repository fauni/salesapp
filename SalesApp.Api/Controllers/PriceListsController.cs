using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;

namespace SalesApp.Api.Controllers;

// SAP price lists (OPLN) — GET /b1s/v1/PriceLists. Read live from SAP, no
// local cache. Used by the mobile app to let the user pick which price list
// to price items against (see ItemsController's priceList query param).
[ApiController]
[Route("api/pricelists")]
[Authorize]
public class PriceListsController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;

    private const string PriceListSelect = "PriceListNo,PriceListName,Currency,BasePriceList,Factor";

    public PriceListsController(ISapServiceLayerClient sapClient) => _sapClient = sapClient;

    // GET /api/pricelists
    [HttpGet]
    public async Task<ActionResult<IEnumerable<PriceListDto>>> List(CancellationToken ct)
    {
        var query = $"PriceLists?$select={PriceListSelect}&$orderby=PriceListName";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var result = doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(MapPriceList)
            .ToList();

        return Ok(result);
    }

    // GET /api/pricelists/{code}
    [HttpGet("{code:int}")]
    public async Task<ActionResult<PriceListDto>> GetByCode(int code, CancellationToken ct)
    {
        try
        {
            var json = await _sapClient.GetAsync(
                $"PriceLists({code})?$select={PriceListSelect}", ct);

            using var doc = JsonDocument.Parse(json);
            return Ok(MapPriceList(doc.RootElement));
        }
        catch (Core.Exceptions.SapException ex) when (ex.StatusCode == 404)
        {
            return NotFound();
        }
    }

    private static PriceListDto MapPriceList(JsonElement e) => new()
    {
        Code = Int(e, "PriceListNo") ?? 0,
        Name = Str(e, "PriceListName") ?? string.Empty,
        Currency = Str(e, "Currency"),
        BasePriceList = Int(e, "BasePriceList"),
        Factor = Dec(e, "Factor")
    };

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
