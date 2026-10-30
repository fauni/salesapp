using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SalesApp.Core.Exceptions;
using SalesApp.Core.Interfaces;

namespace SalesApp.Infrastructure.Catalog;

// Singleton in-memory cache of SAP's warehouses (the client has ~36, so all of
// them fit in one small map). Unlike CatalogResolverService it doesn't use the
// CatalogCache table: that one is keyed by int and resolves one code at a time,
// while warehouse codes are strings and the catalog needs every name at once.
//
// Singleton, so it can't take the (typed, transient) ISapServiceLayerClient in
// its constructor — it opens a scope per refresh instead.
public class WarehouseCatalog : IWarehouseCatalog
{
    private static readonly TimeSpan Ttl = TimeSpan.FromHours(6);

    // Service Layer pages at 20 rows; follow pages until SAP stops sending a
    // nextLink. The cap only guards against a runaway loop.
    private const int MaxPages = 50;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<WarehouseCatalog> _logger;
    private readonly SemaphoreSlim _refreshLock = new(1, 1);

    private IReadOnlyDictionary<string, WarehouseInfo> _warehouses =
        new Dictionary<string, WarehouseInfo>(StringComparer.OrdinalIgnoreCase);
    private DateTime _loadedAtUtc = DateTime.MinValue;

    public WarehouseCatalog(IServiceScopeFactory scopeFactory, ILogger<WarehouseCatalog> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task<IReadOnlyDictionary<string, WarehouseInfo>> GetAllAsync(CancellationToken ct = default)
    {
        if (IsFresh) return _warehouses;

        await _refreshLock.WaitAsync(ct);
        try
        {
            if (IsFresh) return _warehouses; // another request refreshed meanwhile

            try
            {
                _warehouses = await LoadFromSapAsync(ct);
                _loadedAtUtc = DateTime.UtcNow;
            }
            catch (SapException ex)
            {
                // Keep serving the previous copy; retry on the next call.
                _logger.LogWarning(ex, "Could not load SAP warehouses; serving {Count} cached", _warehouses.Count);
            }
            return _warehouses;
        }
        finally
        {
            _refreshLock.Release();
        }
    }

    private bool IsFresh => DateTime.UtcNow - _loadedAtUtc < Ttl;

    private async Task<IReadOnlyDictionary<string, WarehouseInfo>> LoadFromSapAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var sap = scope.ServiceProvider.GetRequiredService<ISapServiceLayerClient>();

        var result = new Dictionary<string, WarehouseInfo>(StringComparer.OrdinalIgnoreCase);
        var read = 0; // rows consumed so far = next $skip
        for (var page = 0; page < MaxPages; page++)
        {
            var json = await sap.GetAsync(
                "Warehouses?$select=WarehouseCode,WarehouseName,Inactive&$orderby=WarehouseCode"
                + $"&$skip={read}", ct);

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            var rows = 0;
            foreach (var w in root.GetProperty("value").EnumerateArray())
            {
                rows++;
                read++;
                var code = Str(w, "WarehouseCode");
                if (string.IsNullOrWhiteSpace(code)) continue;
                result[code] = new WarehouseInfo(
                    code,
                    Str(w, "WarehouseName") ?? code,
                    Str(w, "Inactive") == "tYES");
            }

            if (rows == 0 || !root.TryGetProperty("odata.nextLink", out _)) break;
        }
        return result;
    }

    private static string? Str(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.String
            ? v.GetString()
            : null;
}
