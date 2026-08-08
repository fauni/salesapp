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
    }
}
