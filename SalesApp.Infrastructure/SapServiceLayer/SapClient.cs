using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using SalesApp.Core.Exceptions;
using SalesApp.Core.Interfaces;

namespace SalesApp.Infrastructure.SapServiceLayer;

public class SapClient : ISapServiceLayerClient
{
    private readonly HttpClient _httpClient;
    private readonly SapSessionManager _sessionManager;
    private readonly ISapAccountContext _accountContext;
    private readonly ILogger<SapClient> _logger;

    public SapClient(
        HttpClient httpClient,
        SapSessionManager sessionManager,
        ISapAccountContext accountContext,
        ILogger<SapClient> logger)
    {
        _httpClient = httpClient;
        _sessionManager = sessionManager;
        _accountContext = accountContext;
        _logger = logger;
    }

    public Task<string> GetAsync(string resourcePath, CancellationToken ct = default) =>
        SendAsync(HttpMethod.Get, resourcePath, null, ct);

    public Task<string> PostAsync(string resourcePath, object body, CancellationToken ct = default) =>
        SendAsync(HttpMethod.Post, resourcePath, body, ct);

    public Task<string> PatchAsync(string resourcePath, object body, CancellationToken ct = default) =>
        SendAsync(HttpMethod.Patch, resourcePath, body, ct);

    private async Task<string> SendAsync(HttpMethod method, string resourcePath, object? body, CancellationToken ct)
    {
        var response = await ExecuteAsync(method, resourcePath, body, ct);

        // Session expired mid-flight (e.g. SAP restarted, or timeout was shorter
        // than expected): force a fresh login and retry exactly once.
        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            await _sessionManager.ForceRenewAsync(_accountContext.SapAccountId, ct);
            response = await ExecuteAsync(method, resourcePath, body, ct);
        }

        // Surface SAP's own error body instead of swallowing it (CLAUDE.md gotcha).
        // SapException carries the status + JSON so controllers can map it
        // (e.g. 400 validation -> BadRequest, 404 -> NotFound).
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync(ct);
            throw new SapException((int)response.StatusCode, errorBody);
        }

        return await response.Content.ReadAsStringAsync(ct);
    }

    private async Task<HttpResponseMessage> ExecuteAsync(HttpMethod method, string resourcePath, object? body, CancellationToken ct)
    {
        // The caller's SAP account (several app users may share one); null =
        // the technical account from Parameters.
        var cookie = await _sessionManager.GetSessionCookieAsync(_accountContext.SapAccountId, ct);
        _httpClient.BaseAddress ??= new Uri(_sessionManager.BaseUrl.TrimEnd('/') + "/");

        var request = new HttpRequestMessage(method, resourcePath);
        request.Headers.Add("Cookie", cookie);

        string? json = null;
        if (body != null)
        {
            json = JsonSerializer.Serialize(body);
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        }

        // Diagnostic: which SAP URL we're hitting and the request body (if any).
        // GET calls have no body. Note the body may contain business data — keep
        // this at Information for troubleshooting; drop to Debug if it's too noisy.
        var absoluteUrl = new Uri(_httpClient.BaseAddress!, resourcePath);
        _logger.LogInformation("SAP {Method} {Url} | Body: {Body}",
            method.Method, absoluteUrl, json ?? "(none)");

        return await _httpClient.SendAsync(request, ct);
    }
}