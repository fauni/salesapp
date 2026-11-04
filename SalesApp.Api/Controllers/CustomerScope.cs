using System.Security.Claims;

namespace SalesApp.Api.Controllers;

// Which SAP customers the caller may see and order for (client decision
// 2026-11-04): a rep only gets the customers assigned to their own SAP
// salesperson (OCRD.SlpCode = the user's SalesEmployeeCode, from the JWT).
//   - Administrator          -> all customers
//   - rep with a code        -> only customers with that SalesPersonCode
//   - rep without a code     -> none
// Customers with no salesperson in SAP (-1) are therefore visible only to
// Administrators.
public readonly record struct CustomerScope(bool All, int? SalesPersonCode)
{
    public bool None => !All && SalesPersonCode is null;

    public static CustomerScope For(ClaimsPrincipal user)
    {
        if (user.IsInRole("Administrator")) return new(true, null);
        return int.TryParse(user.FindFirst("salesEmployeeCode")?.Value, out var code) && code > 0
            ? new(false, code)
            : new(false, null);
    }

    // OData condition to AND into a BusinessPartners filter; null = no
    // restriction. Never called for None — callers short-circuit that case.
    public string? ODataFilter => All ? null : $"SalesPersonCode eq {SalesPersonCode}";

    public bool Allows(int? customerSalesPersonCode) =>
        All || (SalesPersonCode is int code && customerSalesPersonCode == code);
}
