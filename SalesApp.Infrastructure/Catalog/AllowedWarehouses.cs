using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SalesApp.Infrastructure.Persistence;

namespace SalesApp.Infrastructure.Catalog;

// Singleton cache of the AllowedWarehouses table. The item catalog reads it on
// every search/scroll, so it's kept in memory. WarehousesController invalidates
// it on save; the short TTL only covers rows edited directly in SQL.
//
// Singleton, so it can't take the scoped AppDbContext in its constructor — it
// opens a scope per reload instead (same as WarehouseCatalog).
public class AllowedWarehouses : IAllowedWarehouses
{
    private static readonly TimeSpan Ttl = TimeSpan.FromMinutes(5);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly SemaphoreSlim _refreshLock = new(1, 1);

    private IReadOnlySet<string> _codes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    private DateTime _loadedAtUtc = DateTime.MinValue;

    public AllowedWarehouses(IServiceScopeFactory scopeFactory) => _scopeFactory = scopeFactory;

    public async Task<IReadOnlySet<string>> GetCodesAsync(CancellationToken ct = default)
    {
        if (IsFresh) return _codes;

        await _refreshLock.WaitAsync(ct);
        try
        {
            if (IsFresh) return _codes; // another request reloaded meanwhile

            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var codes = await db.AllowedWarehouses
                .AsNoTracking()
                .Select(w => w.SapWarehouseCode)
                .ToListAsync(ct);

            _codes = new HashSet<string>(codes, StringComparer.OrdinalIgnoreCase);
            _loadedAtUtc = DateTime.UtcNow;
            return _codes;
        }
        finally
        {
            _refreshLock.Release();
        }
    }

    public void Invalidate() => _loadedAtUtc = DateTime.MinValue;

    private bool IsFresh => DateTime.UtcNow - _loadedAtUtc < Ttl;
}
