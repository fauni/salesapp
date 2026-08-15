using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;

namespace SalesApp.Api.Controllers;

// "Sucursal" = SAP Distribution Rules (OOCR) — GET /b1s/v1/DistributionRules.
// Not SAP Branches (multi-branch is confirmed out of scope for this client);
// this is a distribution-rule dimension used to tag order lines. Read live
// from SAP, no local cache.
[ApiController]
[Route("api/branches")]
[Authorize]
public class BranchesController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;

    public BranchesController(ISapServiceLayerClient sapClient) => _sapClient = sapClient;

    // GET /api/branches
    // Active distribution rules only (Active eq 'tYES'), restricted to
    // InWhichDimension = 2 — that's the "Sucursal" dimension for this client
    // (other dimensions are unrelated distribution rules, not branches).
    [HttpGet]
    public async Task<ActionResult<IEnumerable<BranchDto>>> List(CancellationToken ct)
    {
        var query = "DistributionRules?$select=FactorCode,FactorDescription,Active,InWhichDimension"
                  + $"&$filter={Uri.EscapeDataString("Active eq 'tYES' and InWhichDimension eq 2")}"
                  + "&$orderby=FactorDescription";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var result = doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(e => new BranchDto
            {
                Code = e.TryGetProperty("FactorCode", out var c) && c.ValueKind == JsonValueKind.String
                       ? c.GetString() ?? string.Empty
                       : string.Empty,
                Name = e.TryGetProperty("FactorDescription", out var n) && n.ValueKind == JsonValueKind.String
                       ? n.GetString() ?? string.Empty
                       : string.Empty
            })
            .ToList();

        return Ok(result);
    }
}
