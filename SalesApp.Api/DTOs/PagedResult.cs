namespace SalesApp.Api.DTOs;

// Generic paginated envelope. TotalCount lets the mobile app know how many rows
// exist across all pages (comes from SAP's $inlinecount).
public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; set; } = new List<T>();
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalCount { get; set; }
}
