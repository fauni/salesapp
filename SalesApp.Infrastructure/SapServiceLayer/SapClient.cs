using System.Net;
using System.Text;
using System.Text.Json;
using SalesApp.Core.Interfaces;

namespace SalesApp.Infrastructure.SapServiceLayer;

public class SapClient : ISapServiceLayerClient
{
    private readonly HttpClient _httpClient;
    private readonly SapSessionManager _sessionManager;

    public SapClient(HttpClient httpClient, SapSessionManager sessionManager)
    {
        _httpClient = httpClient;
        _sessionManager = sessionManager;
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
            await _sessionManager.ForceRenewAsync(ct);
            response = await ExecuteAsync(method, resourcePath, body, ct);
        }

        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsStringAsync(ct);
    }

    private async Task<HttpResponseMessage> ExecuteAsync(HttpMethod method, string resourcePath, object? body, CancellationToken ct)
    {
        var cookie = await _sessionManager.GetSessionCookieAsync(ct);
        _httpClient.BaseAddress ??= new Uri(_sessionManager.BaseUrl.TrimEnd('/') + "/");

        var request = new HttpRequestMessage(method, resourcePath);
        request.Headers.Add("Cookie", cookie);

        if (body != null)
        {
            var json = JsonSerializer.Serialize(body);
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        }

        return await _httpClient.SendAsync(request, ct);
    }
}