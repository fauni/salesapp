using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;
using SalesApp.Infrastructure.Catalog;

namespace SalesApp.Api.Controllers;

// Customers = SAP Business Partners with CardType 'cCustomer'. We never hand
// SAP's raw JSON to the mobile app (RF-22/RF-23) — every SAP response is parsed
// and projected into our own DTOs (CustomerDto / CustomerContactDto).
[ApiController]
[Route("api/customers")]
[Authorize]
public class CustomersController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;
    private readonly ICatalogResolverService _catalogResolver;

    // Fields we actually surface — keep the $select tight so SAP returns less
    // and we never accidentally leak a field we didn't mean to.
    private const string CustomerSelect =
        "CardCode,CardName,Phone1,Cellular,EmailAddress,FederalTaxID,Currency";

    // Detail additionally needs the catalog codes we resolve to names.
    private const string CustomerDetailSelect =
        CustomerSelect + ",PriceListNum,PayTermsGrpCode,SalesPersonCode";

    public CustomersController(
        ISapServiceLayerClient sapClient, ICatalogResolverService catalogResolver)
    {
        _sapClient = sapClient;
        _catalogResolver = catalogResolver;
    }

    // GET /api/customers?search=  (RF-22)
    [HttpGet]
    public async Task<ActionResult<IEnumerable<CustomerDto>>> Search(
        [FromQuery] string? search, CancellationToken ct)
    {
        // CardType is a SAP enum; the customer value is 'cCustomer'.
        var filter = "CardType eq 'cCustomer'";

        if (!string.IsNullOrWhiteSpace(search))
        {
            // OData string literals escape a single quote by doubling it.
            var s = search.Trim().Replace("'", "''");
            filter += $" and (contains(CardName,'{s}') or contains(CardCode,'{s}'))";
        }

        var query = $"BusinessPartners?$select={CustomerSelect}"
                  + $"&$filter={Uri.EscapeDataString(filter)}"
                  + "&$orderby=CardName&$top=50";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var customers = doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(MapCustomer)
            .ToList();

        return Ok(customers);
    }

    // GET /api/customers/{code}
    // Single customer detail. Resolves PriceListNum / PayTermsGrpCode to their
    // human-readable names via ICatalogResolverService (cached, one keyed SAP
    // lookup each on a cache miss). The list endpoint above never does this.
    [HttpGet("{code}")]
    public async Task<ActionResult<CustomerDetailDto>> Detail(string code, CancellationToken ct)
    {
        var key = code.Replace("'", "''");
        var query = $"BusinessPartners('{Uri.EscapeDataString(key)}')?$select={CustomerDetailSelect}";

        // A non-existent CardCode makes SAP return 404, which SapExceptionFilter
        // maps to a 404 response — no explicit handling needed here.
        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        var e = doc.RootElement;

        var dto = new CustomerDetailDto
        {
            Code = Str(e, "CardCode") ?? string.Empty,
            Name = Str(e, "CardName") ?? string.Empty,
            Phone = Str(e, "Phone1"),
            Cellular = Str(e, "Cellular"),
            Email = Str(e, "EmailAddress"),
            FederalTaxId = Str(e, "FederalTaxID"),
            Currency = Str(e, "Currency"),
            PriceListNum = IntOrNull(e, "PriceListNum"),
            PaymentTermsGroupCode = IntOrNull(e, "PayTermsGrpCode"),
            SalesPersonCode = IntOrNull(e, "SalesPersonCode")
        };

        if (dto.PriceListNum is int priceList)
        {
            var name = await _catalogResolver.GetPriceListNameAsync(priceList, ct);
            dto.PriceListName = string.IsNullOrEmpty(name) ? null : name;
        }

        if (dto.PaymentTermsGroupCode is int payTerms)
        {
            var name = await _catalogResolver.GetPaymentTermsNameAsync(payTerms, ct);
            dto.PaymentTermsGroupName = string.IsNullOrEmpty(name) ? null : name;
        }

        // SAP uses -1 for "no salesperson assigned"; skip resolving in that case.
        if (dto.SalesPersonCode is int slpCode && slpCode > 0)
        {
            var name = await _catalogResolver.GetSalesPersonNameAsync(slpCode, ct);
            dto.SalesPersonName = string.IsNullOrEmpty(name) ? null : name;
        }

        return Ok(dto);
    }

    // GET /api/customers/{code}/contacts  (RF-23)
    // ContactEmployees is a nested collection property on the Business Partner,
    // not a separate entity set, so we fetch the BP and read that array.
    [HttpGet("{code}/contacts")]
    public async Task<ActionResult<IEnumerable<CustomerContactDto>>> Contacts(
        string code, CancellationToken ct)
    {
        var key = code.Replace("'", "''");
        var query = $"BusinessPartners('{Uri.EscapeDataString(key)}')?$select=CardCode,ContactEmployees";

        var json = await _sapClient.GetAsync(query, ct);

        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("ContactEmployees", out var contacts)
            || contacts.ValueKind != JsonValueKind.Array)
        {
            return Ok(Array.Empty<CustomerContactDto>());
        }

        var result = contacts.EnumerateArray().Select(MapContact).ToList();
        return Ok(result);
    }

    private static CustomerDto MapCustomer(JsonElement e) => new()
    {
        Code = Str(e, "CardCode") ?? string.Empty,
        Name = Str(e, "CardName") ?? string.Empty,
        Phone = Str(e, "Phone1"),
        Cellular = Str(e, "Cellular"),
        Email = Str(e, "EmailAddress"),
        FederalTaxId = Str(e, "FederalTaxID"),
        Currency = Str(e, "Currency")
    };

    private static CustomerContactDto MapContact(JsonElement e) => new()
    {
        InternalCode = Int(e, "InternalCode"),
        Name = Str(e, "Name") ?? string.Empty,
        Position = Str(e, "Position"),
        Phone = Str(e, "Phone1"),
        MobilePhone = Str(e, "MobilePhone"),
        Email = Str(e, "E_Mail"),
        Active = Str(e, "Active") == "tYES"
    };

    private static string? Str(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.String
            ? v.GetString()
            : null;

    private static int Int(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.Number
            ? v.GetInt32()
            : 0;

    // Nullable variant: distinguishes "field absent / null" from a real 0 so we
    // don't try to resolve a catalog name for a code SAP didn't send.
    private static int? IntOrNull(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.Number
            ? v.GetInt32()
            : null;
}
