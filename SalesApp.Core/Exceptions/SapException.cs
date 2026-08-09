namespace SalesApp.Core.Exceptions;

// Thrown when SAP Service Layer returns a non-success status. Carries the raw
// response body so callers can surface SAP's own error (e.g. code 206 / a
// document validation message) instead of a bare HttpRequestException that
// swallows it. See CLAUDE.md: "SAP error bodies are worth surfacing".
public class SapException : Exception
{
    public int StatusCode { get; }
    public string ResponseBody { get; }

    public SapException(int statusCode, string responseBody)
        : base($"SAP Service Layer request failed ({statusCode}): {responseBody}")
    {
        StatusCode = statusCode;
        ResponseBody = responseBody;
    }
}
