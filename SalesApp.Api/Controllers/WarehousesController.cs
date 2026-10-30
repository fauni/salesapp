using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
using SalesApp.Core.Entities;
using SalesApp.Infrastructure.Catalog;
using SalesApp.Infrastructure.Persistence;

namespace SalesApp.Api.Controllers;

// Admin-only management of the global AllowedWarehouses list: which SAP
// warehouses the item catalog offers and order lines may use (same list for
// every user). An empty list allows none.
[ApiController]
[Route("api/warehouses")]
[Authorize(Roles = "Administrator")]
public class WarehousesController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IWarehouseCatalog _warehouseCatalog;
    private readonly IAllowedWarehouses _allowedWarehouses;

    public WarehousesController(
        AppDbContext db,
        IWarehouseCatalog warehouseCatalog,
        IAllowedWarehouses allowedWarehouses)
    {
        _db = db;
        _warehouseCatalog = warehouseCatalog;
        _allowedWarehouses = allowedWarehouses;
    }

    // GET /api/warehouses
    // Every active SAP warehouse, flagged with whether it's allowed. Allowed
    // codes no longer active in SAP are listed too, so they can be removed.
    [HttpGet]
    public async Task<ActionResult<IEnumerable<WarehouseDto>>> List(CancellationToken ct)
    {
        var catalog = await _warehouseCatalog.GetAllAsync(ct);
        var allowed = await AllowedCodesAsync(ct);

        var result = catalog.Values
            .Where(w => !w.Inactive || allowed.Contains(w.Code))
            .Select(w => new WarehouseDto
            {
                Code = w.Code,
                Name = w.Name,
                Allowed = allowed.Contains(w.Code)
            })
            .ToList();

        foreach (var code in allowed.Where(c => !catalog.ContainsKey(c)))
            result.Add(new WarehouseDto { Code = code, Name = code, Allowed = true });

        return Ok(result.OrderBy(w => w.Code, StringComparer.OrdinalIgnoreCase));
    }

    // PUT /api/warehouses/allowed
    // Replaces the whole allowed list.
    [HttpPut("allowed")]
    public async Task<ActionResult<IEnumerable<WarehouseDto>>> UpdateAllowed(
        UpdateAllowedWarehousesRequest request, CancellationToken ct)
    {
        var codes = request.Codes
            .Where(c => !string.IsNullOrWhiteSpace(c))
            .Select(c => c.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        // Only codes SAP knows. If the catalog couldn't be loaded (empty map),
        // skip the check rather than block the admin.
        var catalog = await _warehouseCatalog.GetAllAsync(ct);
        var current = await AllowedCodesAsync(ct);
        var unknown = codes
            .Where(c => catalog.Count > 0 && !catalog.ContainsKey(c) && !current.Contains(c))
            .ToList();
        if (unknown.Count > 0)
            return BadRequest(new { message = $"Unknown warehouse: {string.Join(", ", unknown)}." });

        var existing = await _db.AllowedWarehouses.ToListAsync(ct);
        _db.AllowedWarehouses.RemoveRange(
            existing.Where(w => !codes.Contains(w.SapWarehouseCode, StringComparer.OrdinalIgnoreCase)));
        _db.AllowedWarehouses.AddRange(
            codes.Where(c => !existing.Any(w => string.Equals(w.SapWarehouseCode, c, StringComparison.OrdinalIgnoreCase)))
                 .Select(c => new AllowedWarehouse { SapWarehouseCode = c }));

        await _db.SaveChangesAsync(ct);
        _allowedWarehouses.Invalidate();

        return await List(ct);
    }

    // Straight from the DB (not the cache) — admins must see the real state.
    private async Task<HashSet<string>> AllowedCodesAsync(CancellationToken ct)
    {
        var codes = await _db.AllowedWarehouses
            .AsNoTracking()
            .Select(w => w.SapWarehouseCode)
            .ToListAsync(ct);
        return new HashSet<string>(codes, StringComparer.OrdinalIgnoreCase);
    }
}
