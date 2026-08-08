namespace SalesApp.Core.Entities;

public class Parameter
{
    public int Id { get; set; }
    public string Key { get; set; } = string.Empty;    // e.g. "Sap:ServiceLayer:BaseUrl"
    public string Value { get; set; } = string.Empty;  // encrypted at rest if IsEncrypted = true
    public bool IsEncrypted { get; set; }
    public string Group { get; set; } = string.Empty;  // e.g. "Sap", "General"
    public string? Description { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public int? UpdatedById { get; set; }
    public User? UpdatedBy { get; set; }
}
