using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;

namespace SalesApp.Api.Controllers;

// SAP payment terms groups (OCTG) — GET /b1s/v1/PaymentTermsTypes. Read live
// from SAP, no local cache (CatalogResolverService keeps its own name-only
// cache for resolving a single customer's group, this controller is for
// listing/picking a group instead).
[ApiController]
[Route("api/paymentterms")]
[Authorize]
public class PaymentTermsController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;

    private const string PaymentTermsSelect = "GroupNumber,PaymentTermsGroupName";

    public PaymentTermsController(ISapServiceLayerClient sapClient) => _sapClient = sapClient;

    // GET /api/paymentterms
    [HttpGet]
    public async Task<ActionResult<IEnumerable<PaymentTermsDto>>> List(CancellationToken ct)
    {
        var query = $"PaymentTermsTypes?$select={PaymentTermsSelect}&$orderby=PaymentTermsGroupName";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var result = doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(MapPaymentTerms)
            .ToList();

        return Ok(result);
    }

    // GET /api/paymentterms/{code}
    [HttpGet("{code:int}")]
    public async Task<ActionResult<PaymentTermsDto>> GetByCode(int code, CancellationToken ct)
    {
        try
        {
            var json = await _sapClient.GetAsync(
                $"PaymentTermsTypes({code})?$select={PaymentTermsSelect}", ct);

            using var doc = JsonDocument.Parse(json);
            return Ok(MapPaymentTerms(doc.RootElement));
        }
        catch (Core.Exceptions.SapException ex) when (ex.StatusCode == 404)
        {
            return NotFound();
        }
    }

    private static PaymentTermsDto MapPaymentTerms(JsonElement e) => new()
    {
        Code = Int(e, "GroupNumber") ?? 0,
        Name = Str(e, "PaymentTermsGroupName") ?? string.Empty
    };

    private static string? Str(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.String
            ? v.GetString()
            : null;

    private static int? Int(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.Number
            ? v.GetInt32()
            : null;
}
