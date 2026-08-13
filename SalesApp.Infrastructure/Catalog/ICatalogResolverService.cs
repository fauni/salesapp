namespace SalesApp.Infrastructure.Catalog;

// Resolves the human-readable name of SAP catalog codes that live as plain
// Edm.Int32 fields on the Business Partner (PriceListNum / PayTermsGrpCode) and
// so cannot be $expand-ed. Reads from the local CatalogCache first and only
// hits SAP when the entry is missing or older than the configured TTL.
public interface ICatalogResolverService
{
    // priceListNo => PriceLists(priceListNo).PriceListName
    Task<string> GetPriceListNameAsync(int priceListNo, CancellationToken ct = default);

    // groupNumber => PaymentTermsTypes(groupNumber).PaymentTermsGroupName
    Task<string> GetPaymentTermsNameAsync(int groupNumber, CancellationToken ct = default);
}
