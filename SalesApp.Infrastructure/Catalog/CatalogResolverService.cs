using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SalesApp.Core.Entities;
using SalesApp.Core.Exceptions;
using SalesApp.Core.Interfaces;
using SalesApp.Infrastructure.Persistence;

namespace SalesApp.Infrastructure.Catalog;

// Read-through cache over two SAP catalog entities. The actual Service Layer
// HTTP call goes through ISapServiceLayerClient (SapClient), which already owns
// the session cookie via SapSessionManager plus the retry-once-on-401 behaviour
// — resolving here directly against SapSessionManager would duplicate that.
//
// Scoped: it depends on AppDbContext (scoped), so its own lifetime must match.
public class CatalogResolverService : ICatalogResolverService
{
    // Persisted in CatalogCache.CatalogType — do not change once rows exist.
    private const string PriceListType = "PriceList";
    private const string PaymentTermsType = "PaymentTerms";
    private const string SalesPersonType = "SalesPerson";

    private const string TtlParameterKey = "Catalog:CacheTtlHours";
    private static readonly TimeSpan DefaultTtl = TimeSpan.FromHours(6);

    private readonly AppDbContext _db;
    private readonly ISapServiceLayerClient _sap;

    public CatalogResolverService(AppDbContext db, ISapServiceLayerClient sap)
    {
        _db = db;
        _sap = sap;
    }

    public Task<string> GetPriceListNameAsync(int priceListNo, CancellationToken ct = default) =>
        ResolveAsync(
            PriceListType,
            priceListNo,
            // Keyed GET with a tight $select — SAP returns only the name field.
            resourcePath: $"PriceLists({priceListNo})?$select=PriceListNo,PriceListName",
            nameField: "PriceListName",
            ct);

    public Task<string> GetPaymentTermsNameAsync(int groupNumber, CancellationToken ct = default) =>
        ResolveAsync(
            PaymentTermsType,
            groupNumber,
            resourcePath: $"PaymentTermsTypes({groupNumber})?$select=GroupNumber,PaymentTermsGroupName",
            nameField: "PaymentTermsGroupName",
            ct);

    public Task<string> GetSalesPersonNameAsync(int salesEmployeeCode, CancellationToken ct = default) =>
        ResolveAsync(
            SalesPersonType,
            salesEmployeeCode,
            resourcePath: $"SalesPersons({salesEmployeeCode})?$select=SalesEmployeeCode,SalesEmployeeName",
            nameField: "SalesEmployeeName",
            ct);

    private async Task<string> ResolveAsync(
        string catalogType, int code, string resourcePath, string nameField, CancellationToken ct)
    {
        // SAP uses non-positive sentinels (e.g. -1) for "no price list assigned";
        // there is nothing to resolve, so skip both the cache and SAP.
        if (code <= 0) return string.Empty;

        var ttl = await GetTtlAsync(ct);
        var now = DateTime.UtcNow;

        var cached = await _db.CatalogCache
            .FirstOrDefaultAsync(c => c.CatalogType == catalogType && c.Code == code, ct);

        if (cached != null && now - cached.CachedAt < ttl)
            return cached.Name;

        string name;
        try
        {
            var json = await _sap.GetAsync(resourcePath, ct);
            using var doc = JsonDocument.Parse(json);
            name = doc.RootElement.TryGetProperty(nameField, out var v)
                   && v.ValueKind == JsonValueKind.String
                ? v.GetString() ?? string.Empty
                : string.Empty;
        }
        catch (SapException ex) when (ex.StatusCode == 404)
        {
            // Code isn't a valid catalog key in SAP. Serve a stale name if we have
            // one; otherwise there's simply no name to show.
            return cached?.Name ?? string.Empty;
        }

        await UpsertAsync(cached, catalogType, code, name, now, ct);
        return name;
    }

    private async Task UpsertAsync(
        CatalogCacheEntry? existing, string catalogType, int code, string name, DateTime now, CancellationToken ct)
    {
        if (existing == null)
        {
            _db.CatalogCache.Add(new CatalogCacheEntry
            {
                CatalogType = catalogType,
                Code = code,
                Name = name,
                CachedAt = now
            });
        }
        else
        {
            existing.Name = name;
            existing.CachedAt = now;
        }

        try
        {
            await _db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // A concurrent request inserted the same (type, code) first and hit the
            // unique index. The name is resolved either way — drop our duplicate
            // insert so the request still succeeds.
            if (existing == null)
            {
                var entry = _db.ChangeTracker.Entries<CatalogCacheEntry>()
                    .FirstOrDefault(e => e.State == EntityState.Added);
                if (entry != null) entry.State = EntityState.Detached;
            }
        }
    }

    private async Task<TimeSpan> GetTtlAsync(CancellationToken ct)
    {
        // TTL lives in the Parameters table so it can be tuned without a redeploy.
        var raw = await _db.Parameters
            .Where(p => p.Key == TtlParameterKey)
            .Select(p => p.Value)
            .FirstOrDefaultAsync(ct);

        return double.TryParse(
                   raw, System.Globalization.NumberStyles.Any,
                   System.Globalization.CultureInfo.InvariantCulture, out var hours)
               && hours > 0
            ? TimeSpan.FromHours(hours)
            : DefaultTtl;
    }
}
