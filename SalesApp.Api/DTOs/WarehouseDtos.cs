namespace SalesApp.Api.DTOs;

// Admin-only management of the global AllowedWarehouses list. Warehouses are
// SAP's; we only store which codes sales orders may use.

public class WarehouseDto
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool Allowed { get; set; }
}

public class UpdateAllowedWarehousesRequest
{
    // The full list of allowed codes — replaces the current one. Empty = none.
    public List<string> Codes { get; set; } = new();
}
