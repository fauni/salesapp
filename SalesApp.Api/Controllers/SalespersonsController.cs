using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;
using SalesApp.Infrastructure.Persistence;

namespace SalesApp.Api.Controllers;

// Which SAP numbering series a salesperson may use. This reads OUR OWN DB
// (UserSalesSeries), NOT SAP — SAP owns the series catalog, we only store the
// per-user allow-list keyed by SalesEmployeeCode.
[ApiController]
[Route("api/salespersons")]
[Authorize]
public class SalespersonsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ISapServiceLayerClient _sapClient;

    public SalespersonsController(AppDbContext db, ISapServiceLayerClient sapClient)
    {
        _db = db;
        _sapClient = sapClient;
    }

    // GET /api/salespersons
    // Live list of active SAP salespersons (OSLP) for the order-summary picker.
    // Excludes SAP's -1 "No Sales Employee" sentinel.
    [HttpGet]
    public async Task<ActionResult<IEnumerable<SalesPersonDto>>> List(CancellationToken ct)
    {
        var query = "SalesPersons?$select=SalesEmployeeCode,SalesEmployeeName,Active"
                  + $"&$filter={Uri.EscapeDataString("Active eq 'tYES' and SalesEmployeeCode gt 0")}"
                  + "&$orderby=SalesEmployeeName";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var result = doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(e => new SalesPersonDto
            {
                Code = e.TryGetProperty("SalesEmployeeCode", out var c)
                       && c.ValueKind == JsonValueKind.Number ? c.GetInt32() : 0,
                Name = e.TryGetProperty("SalesEmployeeName", out var n)
                       && n.ValueKind == JsonValueKind.String ? n.GetString() ?? string.Empty : string.Empty
            })
            .ToList();

        return Ok(result);
    }

    // GET /api/salespersons/{code}/series
    // {code} is the SAP SalesEmployeeCode. We only ever serve the series of the
    // CURRENTLY AUTHENTICATED user — the code in the route must match the
    // salesEmployeeCode claim in the JWT, otherwise a rep could read someone
    // else's allow-list.
    [HttpGet("{code}/series")]
    public async Task<ActionResult<IEnumerable<SalesSeriesDto>>> GetSeries(
        string code, CancellationToken ct)
    {
        var jwtCode = User.FindFirst("salesEmployeeCode")?.Value;

        // User isn't linked to a SAP salesperson — nothing to serve.
        if (string.IsNullOrEmpty(jwtCode))
            return Forbid();

        // Prevent reading another salesperson's series by passing a different code.
        if (!string.Equals(code, jwtCode, StringComparison.Ordinal))
            return Forbid();

        var series = await _db.UserSalesSeries
            .Where(s => s.User.SalesEmployeeCode == jwtCode)
            .OrderBy(s => s.SapSeriesName)
            .Select(s => new SalesSeriesDto
            {
                SapSeriesId = s.SapSeriesId,
                SapSeriesName = s.SapSeriesName
            })
            .ToListAsync(ct);

        return Ok(series);
    }
}
