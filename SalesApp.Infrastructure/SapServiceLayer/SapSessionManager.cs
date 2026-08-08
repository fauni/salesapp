using System.Net.Http.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SalesApp.Core.Entities;
using SalesApp.Infrastructure.Persistence;
using SalesApp.Infrastructure.SapServiceLayer.SapDtos;

namespace SalesApp.Infrastructure.SapServiceLayer;

// Registered as Singleton: one shared session for the whole app instead of
// logging in to SAP on every request. Config is loaded once from the
// Parameters table (see AppDbContext seed) and cached in memory.
public class SapSessionManager
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IDataProtector _protector;
    private readonly SemaphoreSlim _lock = new(1, 1);

    // SAP Service Layer is case-sensitive on the Login body field names
    // (CompanyDB / UserName / Password). PostAsJsonAsync's default options use
    // JsonSerializerDefaults.Web = camelCase, which would send companyDB/userName/
    // password and make SAP reject the login as "Invalid login credential" (206).
    // Serialize with the property names exactly as declared.
    private static readonly System.Text.Json.JsonSerializerOptions SapJsonOptions = new()
    {
        PropertyNamingPolicy = null
    };

    private string? _sessionCookie;
    private DateTime _expiresAtUtc = DateTime.MinValue;
    private string _baseUrl = string.Empty;
    private string _companyDb = string.Empty;
    private string _username = string.Empty;
    private string _password = string.Empty;
    private bool _configLoaded;

    public SapSessionManager(
        IHttpClientFactory httpClientFactory,
        IServiceScopeFactory scopeFactory,
        IDataProtectionProvider dataProtectionProvider)
    {
        _httpClientFactory = httpClientFactory;
        _scopeFactory = scopeFactory;
        // Purpose string must match whatever encrypts the value when it's saved
        // from the admin panel (Parameters.IsEncrypted = true).
        _protector = dataProtectionProvider.CreateProtector("SalesApp.SapCredentials");
    }

    // Called after Parameters rows are updated (e.g. from the config endpoint or
    // the future admin panel) so the next request reloads fresh values instead
    // of keeping stale ones cached in memory.
    public void InvalidateConfig()
    {
        _configLoaded = false;
        _sessionCookie = null;
        _expiresAtUtc = DateTime.MinValue;
    }

    public async Task<(string BaseUrl, string CompanyDb, string UsernameMasked, int PasswordLength)> GetLoadedConfigAsync(CancellationToken ct = default)
    {
        await EnsureConfigLoadedAsync(ct);
        var maskedUsername = _username.Length <= 2
            ? new string('*', _username.Length)
            : _username[0] + new string('*', _username.Length - 2) + _username[^1];
        return (_baseUrl, _companyDb, maskedUsername, _password.Length);
    }

    public string BaseUrl => _baseUrl;

    public async Task<string> GetSessionCookieAsync(CancellationToken ct = default)
    {
        await EnsureConfigLoadedAsync(ct);

        if (_sessionCookie != null && DateTime.UtcNow < _expiresAtUtc)
            return _sessionCookie;

        await _lock.WaitAsync(ct);
        try
        {
            // Re-check: another request may have already renewed while we waited
            if (_sessionCookie != null && DateTime.UtcNow < _expiresAtUtc)
                return _sessionCookie;

            await LoginAsync(ct);
            return _sessionCookie!;
        }
        finally
        {
            _lock.Release();
        }
    }

    // Called by SapClient when SAP replies 401 mid-flight (session expired early
    // or was killed on SAP's side).
    public async Task ForceRenewAsync(CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try { await LoginAsync(ct); }
        finally { _lock.Release(); }
    }

    private async Task EnsureConfigLoadedAsync(CancellationToken ct)
    {
        if (_configLoaded) return;

        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var parameters = await db.Parameters.Where(p => p.Group == "Sap").ToListAsync(ct);

        _baseUrl = GetValue(parameters, "Sap:ServiceLayer:BaseUrl");
        _companyDb = GetValue(parameters, "Sap:ServiceLayer:CompanyDb");
        _username = Decrypt(GetValue(parameters, "Sap:ServiceLayer:Username"));
        _password = Decrypt(GetValue(parameters, "Sap:ServiceLayer:Password"));
        _configLoaded = true;
    }

    private static string GetValue(List<Parameter> parameters, string key) =>
        parameters.FirstOrDefault(p => p.Key == key)?.Value
            ?? throw new InvalidOperationException($"Missing required parameter: {key}");

    private string Decrypt(string value) =>
        string.IsNullOrEmpty(value) ? value : _protector.Unprotect(value);

    private async Task LoginAsync(CancellationToken ct)
    {
        var client = _httpClientFactory.CreateClient("SapServiceLayer");
        client.BaseAddress = new Uri(_baseUrl.TrimEnd('/') + "/");

        var payload = new SapLoginRequest { CompanyDB = _companyDb, UserName = _username, Password = _password };
        var response = await client.PostAsJsonAsync("Login", payload, SapJsonOptions, ct);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync(ct);
            throw new InvalidOperationException(
                $"SAP Service Layer Login failed ({(int)response.StatusCode} {response.StatusCode}): {errorBody}");
        }

        var body = await response.Content.ReadFromJsonAsync<SapLoginResponse>(cancellationToken: ct);

        var setCookies = response.Headers.TryGetValues("Set-Cookie", out var values)
            ? values
            : Enumerable.Empty<string>();

        var b1Session = setCookies.FirstOrDefault(c => c.StartsWith("B1SESSION"))?.Split(';')[0];
        var routeId = setCookies.FirstOrDefault(c => c.StartsWith("ROUTEID"))?.Split(';')[0];

        if (b1Session == null)
            throw new InvalidOperationException("SAP Login succeeded but no B1SESSION cookie was returned.");

        // ROUTEID is only present in load-balanced SAP setups; include it when it exists
        // so subsequent calls hit the same SAP node.
        _sessionCookie = routeId != null ? $"{b1Session}; {routeId}" : b1Session;

        var timeoutMinutes = body?.SessionTimeout > 0 ? body.SessionTimeout : 30;
        _expiresAtUtc = DateTime.UtcNow.AddMinutes(timeoutMinutes - 1); // 1-minute safety margin
    }
}