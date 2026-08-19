namespace SalesApp.Api.DTOs;

// A SAP payment terms group (OCTG / PaymentTermsTypes) — read live from SAP,
// not our DB.
public class PaymentTermsDto
{
    public int Code { get; set; }                      // SAP GroupNumber
    public string Name { get; set; } = string.Empty;    // SAP PaymentTermsGroupName
}
