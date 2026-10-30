namespace SalesApp.Infrastructure.Catalog;

// The global list of SAP warehouse codes sales orders may use (AllowedWarehouses
// table), cached in memory. Empty set = no warehouse allowed.
public interface IAllowedWarehouses
{
    Task<IReadOnlySet<string>> GetCodesAsync(CancellationToken ct = default);

    // Call after changing the table so the next read reloads it.
    void Invalidate();
}
