using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
using SalesApp.Core.Entities;
using SalesApp.Infrastructure.Persistence;
using SalesApp.Infrastructure.SapServiceLayer;

namespace SalesApp.Api.Controllers;

// Admin-only CRUD for SapAccounts: the SAP users the backend logs in to the
// Service Layer as, assigned to SalesApp users via User.SapAccountId (several
// users may share one). Credentials are encrypted with the same purpose string
// as Parameters — "SalesApp.SapCredentials", never change it. Every save of
// new credentials is verified with a real SAP login first, so bad ones are
// rejected with SAP's own error instead of breaking the assigned users later.
[ApiController]
[Route("api/sap-accounts")]
[Authorize(Roles = "Administrator")]
public class SapAccountsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IDataProtector _protector;
    private readonly SapSessionManager _sessionManager;

    public SapAccountsController(
        AppDbContext db,
        IDataProtectionProvider dataProtectionProvider,
        SapSessionManager sessionManager)
    {
        _db = db;
        _protector = dataProtectionProvider.CreateProtector("SalesApp.SapCredentials");
        _sessionManager = sessionManager;
    }

    // GET /api/sap-accounts
    [HttpGet]
    public async Task<ActionResult<IEnumerable<SapAccountDto>>> List(CancellationToken ct)
    {
        var accounts = await _db.SapAccounts
            .OrderBy(a => a.Name)
            .Select(a => new { Account = a, UserCount = a.Users.Count })
            .ToListAsync(ct);

        return Ok(accounts.Select(x => ToDto(x.Account, x.UserCount)));
    }

    // POST /api/sap-accounts
    [HttpPost]
    public async Task<ActionResult<SapAccountDto>> Create(
        CreateSapAccountRequest request, CancellationToken ct)
    {
        var name = request.Name.Trim();
        var username = request.Username.Trim();
        if (name.Length == 0) return BadRequest(new { message = "Name is required." });
        if (username.Length == 0) return BadRequest(new { message = "SAP username is required." });
        if (string.IsNullOrEmpty(request.Password))
            return BadRequest(new { message = "SAP password is required." });
        if (await _db.SapAccounts.AnyAsync(a => a.Name == name, ct))
            return BadRequest(new { message = "That name is already taken." });

        var loginError = await TestLoginAsync(username, request.Password, ct);
        if (loginError != null) return BadRequest(new { message = loginError });

        var account = new SapAccount
        {
            Name = name,
            Username = _protector.Protect(username),
            Password = _protector.Protect(request.Password),
            IsActive = request.IsActive
        };
        _db.SapAccounts.Add(account);
        await _db.SaveChangesAsync(ct);

        return Ok(ToDto(account, 0));
    }

    // PUT /api/sap-accounts/{id}
    [HttpPut("{id:int}")]
    public async Task<ActionResult<SapAccountDto>> Update(
        int id, UpdateSapAccountRequest request, CancellationToken ct)
    {
        var account = await _db.SapAccounts.FirstOrDefaultAsync(a => a.Id == id, ct);
        if (account == null) return NotFound(new { message = "SAP account not found." });

        var name = request.Name.Trim();
        var username = request.Username.Trim();
        if (name.Length == 0) return BadRequest(new { message = "Name is required." });
        if (username.Length == 0) return BadRequest(new { message = "SAP username is required." });
        if (await _db.SapAccounts.AnyAsync(a => a.Name == name && a.Id != id, ct))
            return BadRequest(new { message = "That name is already taken." });

        var currentUsername = _protector.Unprotect(account.Username);
        var passwordChanged = !string.IsNullOrEmpty(request.Password);
        var password = passwordChanged ? request.Password! : _protector.Unprotect(account.Password);

        // Only re-verify against SAP when the credentials actually change.
        if (passwordChanged || username != currentUsername)
        {
            var loginError = await TestLoginAsync(username, password, ct);
            if (loginError != null) return BadRequest(new { message = loginError });
        }

        account.Name = name;
        account.Username = _protector.Protect(username);
        account.Password = _protector.Protect(password);
        account.IsActive = request.IsActive;
        account.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        // Assigned users pick up the new credentials (or fall back to the
        // technical account if deactivated) on their next SAP call.
        _sessionManager.InvalidateAccount(id);

        var userCount = await _db.Users.CountAsync(u => u.SapAccountId == id, ct);
        return Ok(ToDto(account, userCount));
    }

    // DELETE /api/sap-accounts/{id} — only when no user is assigned to it
    // (deactivate it instead otherwise).
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        var account = await _db.SapAccounts.FirstOrDefaultAsync(a => a.Id == id, ct);
        if (account == null) return NotFound(new { message = "SAP account not found." });

        if (await _db.Users.AnyAsync(u => u.SapAccountId == id, ct))
            return BadRequest(new { message = "The SAP account is assigned to users. Unassign them or deactivate it instead." });

        _db.SapAccounts.Remove(account);
        await _db.SaveChangesAsync(ct);
        _sessionManager.InvalidateAccount(id);

        return NoContent();
    }

    // --- helpers ---

    // SAP's own login error (e.g. code 206 = invalid credentials), or null if OK.
    private async Task<string?> TestLoginAsync(string username, string password, CancellationToken ct)
    {
        try
        {
            await _sessionManager.TestLoginAsync(username, password, ct);
            return null;
        }
        catch (InvalidOperationException ex)
        {
            return ex.Message;
        }
        catch (HttpRequestException ex)
        {
            return $"Could not reach SAP Service Layer: {ex.Message}";
        }
    }

    private SapAccountDto ToDto(SapAccount account, int userCount) => new()
    {
        Id = account.Id,
        Name = account.Name,
        Username = _protector.Unprotect(account.Username),
        IsActive = account.IsActive,
        UserCount = userCount,
        UpdatedAt = account.UpdatedAt
    };
}
