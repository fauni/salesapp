using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
using SalesApp.Core.Entities;
using SalesApp.Core.Services;
using SalesApp.Infrastructure.Persistence;

namespace SalesApp.Api.Controllers;

// Admin-only CRUD for SalesApp's own Users (our DB — NOT SAP users, see
// CLAUDE.md). Replaces the temporary SeedController for anything beyond
// bootstrapping the very first Administrator. Only one Role per user is
// supported (mirrors what SeedController/AuthController already assume);
// UserSalesSeries management is out of scope here — separate iteration.
[ApiController]
[Route("api/users")]
[Authorize(Roles = "Administrator")]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _db;

    public UsersController(AppDbContext db) => _db = db;

    // GET /api/users
    [HttpGet]
    public async Task<ActionResult<IEnumerable<UserDto>>> List(CancellationToken ct)
    {
        var users = await _db.Users
            .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
            .OrderBy(u => u.Username)
            .ToListAsync(ct);

        return Ok(users.Select(ToDto));
    }

    // GET /api/users/{id}
    [HttpGet("{id:int}")]
    public async Task<ActionResult<UserDto>> GetById(int id, CancellationToken ct)
    {
        var user = await _db.Users
            .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
            .FirstOrDefaultAsync(u => u.Id == id, ct);

        if (user == null) return NotFound(new { message = "User not found." });
        return Ok(ToDto(user));
    }

    // POST /api/users
    [HttpPost]
    public async Task<ActionResult<UserDto>> Create(CreateUserRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Username))
            return BadRequest(new { message = "Username is required." });
        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 6)
            return BadRequest(new { message = "Password must be at least 6 characters." });

        if (await _db.Users.AnyAsync(u => u.Username == request.Username, ct))
            return BadRequest(new { message = "That username is already taken." });

        var role = await _db.Roles.FirstOrDefaultAsync(r => r.Id == request.RoleId, ct);
        if (role == null)
            return BadRequest(new { message = "Invalid RoleId." });

        var user = new User
        {
            Username = request.Username,
            PasswordHash = PasswordHasher.Hash(request.Password),
            SalesEmployeeCode = string.IsNullOrWhiteSpace(request.SalesEmployeeCode)
                ? null : request.SalesEmployeeCode,
            IsActive = request.IsActive
        };
        user.UserRoles.Add(new UserRole { Role = role });

        _db.Users.Add(user);
        await _db.SaveChangesAsync(ct);

        // Re-read isn't needed — role navigation is already loaded via `role`.
        return CreatedAtAction(nameof(GetById), new { id = user.Id }, ToDto(user));
    }

    // PUT /api/users/{id}
    // Username is intentionally NOT editable here — changing it could lock the
    // editing admin (or anyone) out by accident. Delete/recreate if a username
    // truly needs to change.
    [HttpPut("{id:int}")]
    public async Task<ActionResult<UserDto>> Update(
        int id, UpdateUserRequest request, CancellationToken ct)
    {
        var user = await _db.Users
            .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
            .FirstOrDefaultAsync(u => u.Id == id, ct);
        if (user == null) return NotFound(new { message = "User not found." });

        // Guard against an admin locking themselves out by deactivating their
        // own account.
        if (!request.IsActive && IsCurrentUser(id))
            return BadRequest(new { message = "You can't deactivate your own user." });

        var role = await _db.Roles.FirstOrDefaultAsync(r => r.Id == request.RoleId, ct);
        if (role == null)
            return BadRequest(new { message = "Invalid RoleId." });

        user.SalesEmployeeCode = string.IsNullOrWhiteSpace(request.SalesEmployeeCode)
            ? null : request.SalesEmployeeCode;
        user.IsActive = request.IsActive;

        // Single-role model: swap the existing assignment instead of accumulating.
        var currentRole = user.UserRoles.FirstOrDefault();
        if (currentRole == null)
        {
            user.UserRoles.Add(new UserRole { Role = role });
        }
        else if (currentRole.RoleId != role.Id)
        {
            _db.Set<UserRole>().Remove(currentRole);
            user.UserRoles.Add(new UserRole { Role = role });
        }

        await _db.SaveChangesAsync(ct);
        return Ok(ToDto(user));
    }

    // POST /api/users/{id}/reset-password
    [HttpPost("{id:int}/reset-password")]
    public async Task<IActionResult> ResetPassword(
        int id, ResetPasswordRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length < 6)
            return BadRequest(new { message = "Password must be at least 6 characters." });

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == id, ct);
        if (user == null) return NotFound(new { message = "User not found." });

        user.PasswordHash = PasswordHasher.Hash(request.NewPassword);
        await _db.SaveChangesAsync(ct);

        return Ok(new { message = "Password updated." });
    }

    // --- helpers ---

    private bool IsCurrentUser(int id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(userId, out var currentId) && currentId == id;
    }

    private static UserDto ToDto(User user)
    {
        var role = user.UserRoles.Select(ur => ur.Role).FirstOrDefault();
        return new UserDto
        {
            Id = user.Id,
            Username = user.Username,
            SalesEmployeeCode = user.SalesEmployeeCode,
            IsActive = user.IsActive,
            RoleId = role?.Id ?? 0,
            RoleName = role?.Name ?? string.Empty,
            CreatedAt = user.CreatedAt
        };
    }
}
