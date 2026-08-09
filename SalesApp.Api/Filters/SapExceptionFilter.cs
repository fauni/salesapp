using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using SalesApp.Core.Exceptions;

namespace SalesApp.Api.Filters;

// Turns a SapException (thrown by SapClient on any non-success Service Layer
// response) into a clean HTTP result for EVERY controller, so we don't repeat
// try/catch in each action. SAP's own error message is surfaced under `sap`.
public class SapExceptionFilter : IExceptionFilter
{
    private readonly ILogger<SapExceptionFilter> _logger;

    public SapExceptionFilter(ILogger<SapExceptionFilter> logger) => _logger = logger;

    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not SapException ex)
            return; // let other exceptions fall through to the default handler

        _logger.LogWarning(ex, "SAP Service Layer returned {Status}", ex.StatusCode);

        var sap = ExtractSapMessage(ex.ResponseBody);

        var (status, message) = ex.StatusCode switch
        {
            404 => (StatusCodes.Status404NotFound, "Resource not found in SAP."),
            400 => (StatusCodes.Status400BadRequest, "SAP rejected the request."),
            _ => (StatusCodes.Status502BadGateway, "SAP Service Layer error.")
        };

        context.Result = new ObjectResult(new { message, sap }) { StatusCode = status };
        context.ExceptionHandled = true;
    }

    // SAP error bodies look like {"error":{"code":..,"message":{"value":".."}}}.
    // Return the human message when present, otherwise the raw body.
    private static string ExtractSapMessage(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("error", out var err)
                && err.TryGetProperty("message", out var msg)
                && msg.TryGetProperty("value", out var val)
                && val.ValueKind == JsonValueKind.String)
                return val.GetString() ?? body;
        }
        catch (JsonException) { /* not JSON — fall through to raw body */ }

        return body;
    }
}
