using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SalesApp.Api.DTOs;
using SalesApp.Api.Services;
using SalesApp.Core.Services;
using SalesApp.Infrastructure.Persistence;

namespace SalesApp.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly TokenService _tokenService;

        public AuthController(AppDbContext db, TokenService tokenService)
        {
            _db = db;
            _tokenService = tokenService;
        }

        [HttpPost("login")]
        public async Task<ActionResult<LoginResponse>> Login(LoginRequest request)
        {
            var user = await _db.Users
                .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
                .FirstOrDefaultAsync(u => u.Username == request.Username && u.IsActive);

            if (user == null || !PasswordHasher.Verify(request.Password, user.PasswordHash))
                return Unauthorized(new { message = "Invalid username or password" });

            var roles = user.UserRoles.Select(ur => ur.Role.Name).ToList();
            var token = _tokenService.GenerateToken(user, roles);

            return Ok(new LoginResponse
            {
                Token = token,
                Username = user.Username,
                SalesEmployeeCode = user.SalesEmployeeCode,
                Roles = roles
            });
        }

        // RF-04: transparent re-login. The mobile app calls this with its current
        // (still-valid) JWT to get a fresh one, so the user never re-enters
        // credentials. Because there's no refresh token, the app must refresh
        // BEFORE the token expires — an expired token is rejected here by
        // [Authorize]. Roles/active status are re-read from the DB, so a user
        // deactivated or re-roled since login gets the change on next refresh.
        [Authorize]
        [HttpPost("refresh")]
        public async Task<ActionResult<LoginResponse>> Refresh()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userId, out var id))
                return Unauthorized(new { message = "Invalid token" });

            var user = await _db.Users
                .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
                .FirstOrDefaultAsync(u => u.Id == id && u.IsActive);

            // User was deleted or deactivated after the token was issued.
            if (user == null)
                return Unauthorized(new { message = "User is no longer active" });

            var roles = user.UserRoles.Select(ur => ur.Role.Name).ToList();
            var token = _tokenService.GenerateToken(user, roles);

            return Ok(new LoginResponse
            {
                Token = token,
                Username = user.Username,
                SalesEmployeeCode = user.SalesEmployeeCode,
                Roles = roles
            });
        }
    }
}
