namespace SalesApp.Core.Entities;

public class UserSalesSeries
{
    public int Id { get; set; }

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int SapSeriesId { get; set; }       // Series ID as defined in SAP B1
    public string SapSeriesName { get; set; } = string.Empty; // cached label for display only
}
