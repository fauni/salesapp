namespace SalesApp.Api.DTOs;

// A SAP numbering series this salesperson is allowed to use when creating
// orders. Stored in OUR DB (UserSalesSeries) — we never replicate SAP's series
// catalog locally, only which series each user may pick.
public class SalesSeriesDto
{
    public int SapSeriesId { get; set; }                    // Series ID as defined in SAP B1
    public string SapSeriesName { get; set; } = string.Empty; // cached label for display
}

// A SAP salesperson (OSLP) the rep can assign to an order. Read live from SAP,
// not our DB — used by the order summary's salesperson picker.
public class SalesPersonDto
{
    public int Code { get; set; }                           // SAP SalesEmployeeCode (SlpCode)
    public string Name { get; set; } = string.Empty;        // SAP SalesEmployeeName
}
