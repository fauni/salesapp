namespace SalesApp.Api.DTOs;

// A SAP project (OPRJ) — used for tagging/filtering elsewhere in the app.
// Read live from SAP, not our DB.
public class ProjectDto
{
    public string Code { get; set; } = string.Empty;  // SAP Code
    public string Name { get; set; } = string.Empty;  // SAP Name
}
