namespace SalesApp.Api.DTOs;

// Admin-only management of the SAP users the backend logs in to the Service
// Layer with (SapAccounts). The password is write-only: never returned.

public class SapAccountDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;   // SAP user (decrypted)
    public bool IsActive { get; set; }
    public int UserCount { get; set; }                      // SalesApp users assigned to it
    public DateTime UpdatedAt { get; set; }
}

public class CreateSapAccountRequest
{
    public string Name { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}

public class UpdateSapAccountRequest
{
    public string Name { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    // Null/empty = keep the current password.
    public string? Password { get; set; }
    public bool IsActive { get; set; }
}
