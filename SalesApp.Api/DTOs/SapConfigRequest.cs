namespace SalesApp.Api.DTOs
{
    public class SapConfigRequest
    {
        public string BaseUrl { get; set; } = string.Empty;       // e.g. https://192.168.1.50:50000/b1s/v1
        public string CompanyDb { get; set; } = string.Empty;     // exact SAP company database name
        public string Username { get; set; } = string.Empty;      // SAP integration user
        public string Password { get; set; } = string.Empty;
    }
}
