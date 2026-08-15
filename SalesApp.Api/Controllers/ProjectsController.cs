using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;

namespace SalesApp.Api.Controllers;

// SAP Projects (OPRJ) — GET /b1s/v1/Projects. Read live from SAP, no local cache.
[ApiController]
[Route("api/projects")]
[Authorize]
public class ProjectsController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;

    public ProjectsController(ISapServiceLayerClient sapClient) => _sapClient = sapClient;

    // GET /api/projects
    // Active SAP projects only (Active eq 'tYES').
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ProjectDto>>> List(CancellationToken ct)
    {
        var query = "Projects?$select=Code,Name,Active"
                  + $"&$filter={Uri.EscapeDataString("Active eq 'tYES'")}"
                  + "&$orderby=Name";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var result = doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(e => new ProjectDto
            {
                Code = e.TryGetProperty("Code", out var c) && c.ValueKind == JsonValueKind.String
                       ? c.GetString() ?? string.Empty
                       : string.Empty,
                Name = e.TryGetProperty("Name", out var n) && n.ValueKind == JsonValueKind.String
                       ? n.GetString() ?? string.Empty
                       : string.Empty
            })
            .ToList();

        return Ok(result);
    }
}
