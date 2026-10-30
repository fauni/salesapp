namespace SalesApp.Infrastructure.Catalog;

// One SAP warehouse (Warehouses entity). Only what the app displays/filters on.
public record WarehouseInfo(string Code, string Name, bool Inactive);

// All SAP warehouses keyed by WarehouseCode, cached in memory. Item stock
// (ItemWarehouseInfoCollection) only carries the code, so the item catalog
// joins names from here instead of hitting SAP per warehouse.
public interface IWarehouseCatalog
{
    // Never throws for SAP failures: returns the last good copy (or an empty
    // map) so a names outage degrades to showing codes, not a broken catalog.
    Task<IReadOnlyDictionary<string, WarehouseInfo>> GetAllAsync(CancellationToken ct = default);
}
