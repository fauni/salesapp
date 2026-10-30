namespace SalesApp.Core.Entities;

// A SAP warehouse that sales orders may use. Global (same list for every user).
// Warehouses themselves are SAP's — we only store which codes are allowed.
// An empty table means NO warehouse is allowed (client decision).
public class AllowedWarehouse
{
    public int Id { get; set; }
    public string SapWarehouseCode { get; set; } = string.Empty; // WarehouseCode in SAP (string, not an FK)
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
