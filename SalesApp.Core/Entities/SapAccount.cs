namespace SalesApp.Core.Entities;

// A SAP B1 user the backend logs in to the Service Layer with, on behalf of
// the SalesApp users assigned to it (User.SapAccountId — several users may
// share one). Users without one use the technical account in Parameters.
// BaseUrl/CompanyDb stay global in Parameters; only the credentials vary.
public class SapAccount
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;     // admin-facing label
    public string Username { get; set; } = string.Empty; // encrypted at rest (IDataProtector)
    public string Password { get; set; } = string.Empty; // encrypted at rest (IDataProtector)
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<User> Users { get; set; } = new List<User>();
}
