namespace SalesApp.Api.DTOs;

// A SAP distribution rule (OOCR / DistributionRules) used as "Sucursal" —
// used for tagging/filtering elsewhere in the app. Read live from SAP, not
// our DB.
public class BranchDto
{
    public string Code { get; set; } = string.Empty;  // SAP FactorCode
    public string Name { get; set; } = string.Empty;  // SAP FactorDescription
}
