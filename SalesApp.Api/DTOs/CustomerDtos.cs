namespace SalesApp.Api.DTOs;

// Public shape returned to the mobile app. Deliberately a subset of SAP's
// BusinessPartner — we never hand SAP's raw JSON to the client (RF-22).
public class CustomerDto
{
    public string Code { get; set; } = string.Empty;   // SAP CardCode
    public string Name { get; set; } = string.Empty;   // SAP CardName
    public string? Phone { get; set; }                  // SAP Phone1
    public string? Cellular { get; set; }               // SAP Cellular
    public string? Email { get; set; }                  // SAP EmailAddress
    public string? FederalTaxId { get; set; }           // SAP FederalTaxID
    public string? Currency { get; set; }               // SAP Currency
}

// Single-customer detail. Adds the resolved catalog names (price list / payment
// terms) on top of the list fields — these cost one keyed SAP lookup each, so
// they're only populated by the detail endpoint, never by the list.
public class CustomerDetailDto : CustomerDto
{
    public int? PriceListNum { get; set; }              // SAP PriceListNum (raw code)
    public string? PriceListName { get; set; }          // resolved via ICatalogResolverService
    public int? PaymentTermsGroupCode { get; set; }     // SAP PayTermsGrpCode (raw code)
    public string? PaymentTermsGroupName { get; set; }  // resolved via ICatalogResolverService
    public int? SalesPersonCode { get; set; }           // SAP SalesPersonCode (SlpCode) assigned to the customer
    public string? SalesPersonName { get; set; }        // resolved via ICatalogResolverService
}

// Contact person of a customer (SAP ContactEmployees) — RF-23.
public class CustomerContactDto
{
    public int InternalCode { get; set; }               // SAP InternalCode
    public string Name { get; set; } = string.Empty;    // SAP Name
    public string? Position { get; set; }               // SAP Position
    public string? Phone { get; set; }                  // SAP Phone1
    public string? MobilePhone { get; set; }            // SAP MobilePhone
    public string? Email { get; set; }                  // SAP E_Mail
    public bool Active { get; set; }                    // SAP Active (tYES/tNO)
}
