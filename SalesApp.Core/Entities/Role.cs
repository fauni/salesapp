namespace SalesApp.Core.Entities;

public class Role
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty; // Salesperson, Supervisor, Administrator

    public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
}
