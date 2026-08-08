namespace SalesApp.Core.Entities;

public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string? SalesEmployeeCode { get; set; } // links to SAP SalesPerson
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
    public ICollection<UserSalesSeries> SalesSeries { get; set; } = new List<UserSalesSeries>();
    public ICollection<AuditLog> AuditLogs { get; set; } = new List<AuditLog>();
}
