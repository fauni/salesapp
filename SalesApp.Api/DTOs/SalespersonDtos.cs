namespace SalesApp.Api.DTOs;

// A SAP numbering series this salesperson is allowed to use when creating
// orders. Stored in OUR DB (UserSalesSeries) — we never replicate SAP's series
// catalog locally, only which series each user may pick.
public class SalesSeriesDto
{
    public int SapSeriesId { get; set; }                    // Series ID as defined in SAP B1
    public string SapSeriesName { get; set; } = string.Empty; // cached label for display
}
