using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Core.Interfaces;
using SalesApp.Infrastructure.SapServiceLayer;

namespace SalesApp.Api.Controllers;

// Diagnostic endpoint to confirm the backend can actually reach SAP Service
// Layer through SapSessionManager/SapClient. Kept behind authentication
// (Administrator only) rather than removed - useful later to verify
// connectivity from the client's server without digging into logs.
[ApiController]
[Route("api/sap-test")]
[Authorize(Roles = "Administrator")]
public class SapTestController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;

    public SapTestController(ISapServiceLayerClient sapClient) => _sapClient = sapClient;

    [HttpGet("ping")]
    public async Task<IActionResult> Ping()
    {
        // Cheapest possible real call: ask for just one Business Partner.
        // If this succeeds, login + cookie handling + the actual HTTP call
        // to SAP all worked.
        var json = await _sapClient.GetAsync("BusinessPartners?$top=1&$select=CardCode,CardName");
        return Content(json, "application/json");
    }

    [HttpGet("config-check")]
    public async Task<IActionResult> ConfigCheck([FromServices] SapSessionManager sessionManager)
    {
        // Diagnostic only: confirms what SapSessionManager actually decrypted from
        // Parameters, without ever exposing the real password. Compare BaseUrl,
        // CompanyDb and usernameMasked against what you tested directly in Postman.
        var config = await sessionManager.GetLoadedConfigAsync();
        return Ok(new
        {
            baseUrl = config.BaseUrl,
            companyDb = config.CompanyDb,
            usernameMasked = config.UsernameMasked,
            passwordLength = config.PasswordLength
        });
    }
}