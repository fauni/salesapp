namespace SalesApp.Core.Entities;

// Local read-through cache for SAP catalog lookups whose values are plain
// Edm.Int32 fields on the Business Partner (PriceListNum, PayTermsGrpCode) and
// therefore cannot be $expand-ed. The human-readable name lives in a separate
// SAP entity (PriceLists / PaymentTermsTypes) reachable only by a keyed GET, so
// we cache the resolved name here to avoid one extra SAP round-trip per lookup.
// Service Layer has no change notifications, so freshness is TTL-based
// (see CatalogResolverService + the Catalog:CacheTtlHours parameter).
public class CatalogCacheEntry
{
    public int Id { get; set; }

    // "PriceList" | "PaymentTerms" — see CatalogType constants in the resolver.
    public string CatalogType { get; set; } = string.Empty;

    // SAP key: PriceLists.PriceListNo or PaymentTermsTypes.GroupNumber.
    public int Code { get; set; }

    // Resolved display name (PriceListName / PaymentTermsGroupName).
    public string Name { get; set; } = string.Empty;

    // UTC timestamp of the last successful SAP resolution; drives TTL expiry.
    public DateTime CachedAt { get; set; }
}
