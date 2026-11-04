namespace SalesApp.Api.DTOs;

// Admin-only management of SalesApp's own Users (NOT SAP users — see
// CLAUDE.md). Roles/UserSalesSeries assignment beyond a single RoleId per
// user is out of scope for now (system only ever uses one role per user in
// practice, mirrored by SeedController).

public class UserDto
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string? SalesEmployeeCode { get; set; }
    public int? SapAccountId { get; set; }                  // null = technical account
    public string? SapAccountName { get; set; }
    public bool IsActive { get; set; }
    public int RoleId { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class CreateUserRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? SalesEmployeeCode { get; set; }
    public int? SapAccountId { get; set; }                  // null = technical account
    public int RoleId { get; set; }
    public bool IsActive { get; set; } = true;
}

public class UpdateUserRequest
{
    public string? SalesEmployeeCode { get; set; }
    public int? SapAccountId { get; set; }                  // null = technical account
    public int RoleId { get; set; }
    public bool IsActive { get; set; }
}

public class ResetPasswordRequest
{
    public string NewPassword { get; set; } = string.Empty;
}
