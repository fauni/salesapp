using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
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

    public SalespersonsController(AppDbContext db) => _db = db;

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
