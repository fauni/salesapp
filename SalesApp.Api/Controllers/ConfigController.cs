using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
using SalesApp.Infrastructure.Persistence;
using SalesApp.Infrastructure.SapServiceLayer;

namespace SalesApp.Api.Controllers;

// TEMPORARY: bootstraps the SAP Service Layer connection parameters so we can
// test SapSessionManager end to end. The real admin panel will eventually do
// this through a proper settings screen using the same encryption purpose
// string ("SalesApp.SapCredentials") - do not change that string later or
// previously-saved passwords become undecryptable.
[ApiController]
[Route("api/config")]
public class ConfigController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;
    private readonly IDataProtector _protector;
    private readonly SapSessionManager _sessionManager;

    public ConfigController(
        AppDbContext db,
        IWebHostEnvironment env,
        IDataProtectionProvider dataProtectionProvider,
        SapSessionManager sessionManager)
    {
        _db = db;
        _env = env;
        _protector = dataProtectionProvider.CreateProtector("SalesApp.SapCredentials");
        _sessionManager = sessionManager;
    }

    [HttpPost("sap-service-layer")]
    public async Task<IActionResult> SetSapConfig(SapConfigRequest request)
    {
        if (!_env.IsDevelopment())
            return NotFound();

        await SetParam("Sap:ServiceLayer:BaseUrl", request.BaseUrl.TrimEnd('/'));
        await SetParam("Sap:ServiceLayer:CompanyDb", request.CompanyDb);
        await SetParam("Sap:ServiceLayer:Username", _protector.Protect(request.Username));
        await SetParam("Sap:ServiceLayer:Password", _protector.Protect(request.Password));

        await _db.SaveChangesAsync();
        _sessionManager.InvalidateConfig(); // drop cached values so next call reloads these

        return Ok(new { message = "SAP Service Layer configuration saved." });
    }

    private async Task SetParam(string key, string value)
    {
        var param = await _db.Parameters.FirstOrDefaultAsync(p => p.Key == key)
            ?? throw new InvalidOperationException($"Parameter not seeded: {key}");
        param.Value = value;
        param.UpdatedAt = DateTime.UtcNow;
    }
}