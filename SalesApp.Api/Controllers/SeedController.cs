using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
using SalesApp.Core.Entities;
using SalesApp.Core.Services;
using SalesApp.Infrastructure.Persistence;

namespace SalesApp.Api.Controllers;

// TEMPORARY: only exists to bootstrap the very first Administrator user.
// Remove this controller (or at least this action) before deploying to the
// client's server - it deliberately only works in Development so it can't
// be hit by accident once published.
[ApiController]
[Route("api/auth")]
public class SeedController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;

    public SeedController(AppDbContext db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    [HttpPost("seed-admin")]
    public async Task<IActionResult> SeedAdmin(LoginRequest request)
    {
        if (!_env.IsDevelopment())
            return NotFound();

        if (await _db.Users.AnyAsync())
            return BadRequest(new { message = "Users already exist. Seed endpoint only runs against an empty Users table." });

        var adminRole = await _db.Roles.FirstOrDefaultAsync(r => r.Name == "Administrator");
        if (adminRole == null)
            return BadRequest(new { message = "Administrator role not found. Did the InitialCreate migration run?" });

        var user = new User
        {
            Username = request.Username,
            PasswordHash = PasswordHasher.Hash(request.Password),
            IsActive = true
        };
        user.UserRoles.Add(new UserRole { Role = adminRole });

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        return Ok(new { message = $"Admin user '{user.Username}' created. You can now log in via /api/auth/login." });
    }
}