using System.Collections.Concurrent;
using System.Net.Http.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SalesApp.Core.Entities;
using SalesApp.Infrastructure.Persistence;
using SalesApp.Infrastructure.SapServiceLayer.SapDtos;

namespace SalesApp.Infrastructure.SapServiceLayer;

// Registered as Singleton: one shared Service Layer session PER SAP ACCOUNT
// instead of logging in to SAP on every request. SalesApp users assigned to
// the same SapAccount share its session; users without one (and calls with no
// user at all) share the technical account's session from Parameters.
// BaseUrl/CompanyDb are global (Parameters); config is loaded once and cached.
public class SapSessionManager
{
    // Session key of the technical account (Parameters). SapAccount ids are > 0.
    private const int DefaultAccountKey = 0;

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IDataProtector _protector;
    private readonly SemaphoreSlim _configLock = new(1, 1);

    // SAP Service Layer is case-sensitive on the Login body field names
    // (CompanyDB / UserName / Password). PostAsJsonAsync's default options use
    // JsonSerializerDefaults.Web = camelCase, which would send companyDB/userName/
    // password and make SAP reject the login as "Invalid login credential" (206).
    // Serialize with the property names exactly as declared.
    private static readonly System.Text.Json.JsonSerializerOptions SapJsonOptions = new()
    {
        PropertyNamingPolicy = null
    };

    private readonly ConcurrentDictionary<int, AccountSession> _sessions = new();

    private string _baseUrl = string.Empty;
    private string _companyDb = string.Empty;
    private string _defaultUsername = string.Empty;
    private string _defaultPassword = string.Empty;
    private volatile bool _configLoaded;

    // One per SAP account: its credentials and its live session cookie.
    private sealed class AccountSession
    {
        public required string Username { get; init; }
        public required string Password { get; init; }
        public SemaphoreSlim Lock { get; } = new(1, 1);
        public string? Cookie { get; set; }
        public DateTime ExpiresAtUtc { get; set; } = DateTime.MinValue;
    }

    public SapSessionManager(
        IHttpClientFactory httpClientFactory,
        IServiceScopeFactory scopeFactory,
        IDataProtectionProvider dataProtectionProvider)
    {
        _httpClientFactory = httpClientFactory;
        _scopeFactory = scopeFactory;
        // Purpose string must match whatever encrypts the value when it's saved
        // (Parameters.IsEncrypted = true, SapAccounts.Username/Password).
        _protector = dataProtectionProvider.CreateProtector("SalesApp.SapCredentials");
    }

    // Called after Parameters rows are updated (e.g. from the config endpoint)
    // so the next request reloads fresh values — drops every session, since
    // BaseUrl/CompanyDb are shared by all accounts.
    public void InvalidateConfig()
    {
        _configLoaded = false;
        _sessions.Clear();
    }

    // Called after a SapAccount is edited/deactivated/deleted: its next call
    // re-reads the account from the DB and logs in again.
    public void InvalidateAccount(int sapAccountId) => _sessions.TryRemove(sapAccountId, out _);

    public async Task<(string BaseUrl, string CompanyDb, string UsernameMasked, int PasswordLength)> GetLoadedConfigAsync(CancellationToken ct = default)
    {
        await EnsureConfigLoadedAsync(ct);
        var maskedUsername = _defaultUsername.Length <= 2
            ? new string('*', _defaultUsername.Length)
            : _defaultUsername[0] + new string('*', _defaultUsername.Length - 2) + _defaultUsername[^1];
        return (_baseUrl, _companyDb, maskedUsername, _defaultPassword.Length);
    }

    public string BaseUrl => _baseUrl;

    // sapAccountId null (or an account that no longer exists / is inactive)
    // -> the technical account's session.
    public async Task<string> GetSessionCookieAsync(int? sapAccountId, CancellationToken ct = default)
    {
        var session = await GetAccountSessionAsync(sapAccountId, ct);

        if (session.Cookie != null && DateTime.UtcNow < session.ExpiresAtUtc)
            return session.Cookie;

        await session.Lock.WaitAsync(ct);
        try
        {
            // Re-check: another request may have already renewed while we waited
            if (session.Cookie != null && DateTime.UtcNow < session.ExpiresAtUtc)
                return session.Cookie;

            await RenewAsync(session, ct);
            return session.Cookie!;
        }
        finally
        {
            session.Lock.Release();
        }
    }

    // Called by SapClient when SAP replies 401 mid-flight (session expired early
    // or was killed on SAP's side).
    public async Task ForceRenewAsync(int? sapAccountId, CancellationToken ct = default)
    {
        var session = await GetAccountSessionAsync(sapAccountId, ct);
        await session.Lock.WaitAsync(ct);
        try { await RenewAsync(session, ct); }
        finally { session.Lock.Release(); }
    }

    // Validates SAP credentials before an admin saves them: logs in, then logs
    // straight out so the test doesn't hold a Service Layer session. Throws
    // with SAP's own error (e.g. 206 invalid credentials) on failure.
    public async Task TestLoginAsync(string username, string password, CancellationToken ct = default)
    {
        await EnsureConfigLoadedAsync(ct);
        var (cookie, _) = await LoginAsync(username, password, ct);

        try
        {
            var client = CreateClient();
            using var request = new HttpRequestMessage(HttpMethod.Post, "Logout");
            request.Headers.Add("Cookie", cookie);
            using var _ = await client.SendAsync(request, ct);
        }
        catch (HttpRequestException)
        {
            // Best-effort: an un-logged-out test session just times out in SAP.
        }
    }

    private async Task<AccountSession> GetAccountSessionAsync(int? sapAccountId, CancellationToken ct)
    {
        await EnsureConfigLoadedAsync(ct);

        var key = sapAccountId is > 0 ? sapAccountId.Value : DefaultAccountKey;
        if (_sessions.TryGetValue(key, out var session)) return session;

        session = key == DefaultAccountKey
            ? DefaultSession()
            : await LoadAccountSessionAsync(key, ct) ?? DefaultSession();

        // A racing request may have added it first — keep that one.
        return _sessions.GetOrAdd(key, session);
    }

    // The technical account's session is shared by every caller that falls
    // back to it, so it lives under DefaultAccountKey only.
    private AccountSession DefaultSession() =>
        _sessions.GetOrAdd(DefaultAccountKey,
            _ => new AccountSession { Username = _defaultUsername, Password = _defaultPassword });

    // null when the account doesn't exist or is inactive -> technical account.
    private async Task<AccountSession?> LoadAccountSessionAsync(int sapAccountId, CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var account = await db.SapAccounts.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == sapAccountId && a.IsActive, ct);
        if (account == null) return null;

        return new AccountSession
        {
            Username = Decrypt(account.Username),
            Password = Decrypt(account.Password)
        };
    }

    private async Task EnsureConfigLoadedAsync(CancellationToken ct)
    {
        if (_configLoaded) return;

        await _configLock.WaitAsync(ct);
        try
        {
            if (_configLoaded) return;

            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var parameters = await db.Parameters.Where(p => p.Group == "Sap").ToListAsync(ct);

            _baseUrl = GetValue(parameters, "Sap:ServiceLayer:BaseUrl");
            _companyDb = GetValue(parameters, "Sap:ServiceLayer:CompanyDb");
            _defaultUsername = Decrypt(GetValue(parameters, "Sap:ServiceLayer:Username"));
            _defaultPassword = Decrypt(GetValue(parameters, "Sap:ServiceLayer:Password"));
            _configLoaded = true;
        }
        finally
        {
            _configLock.Release();
        }
    }

    private static string GetValue(List<Parameter> parameters, string key) =>
        parameters.FirstOrDefault(p => p.Key == key)?.Value
            ?? throw new InvalidOperationException($"Missing required parameter: {key}");

    private string Decrypt(string value) =>
        string.IsNullOrEmpty(value) ? value : _protector.Unprotect(value);

    private async Task RenewAsync(AccountSession session, CancellationToken ct)
    {
        var (cookie, timeoutMinutes) = await LoginAsync(session.Username, session.Password, ct);
        session.Cookie = cookie;
        session.ExpiresAtUtc = DateTime.UtcNow.AddMinutes(timeoutMinutes - 1); // 1-minute safety margin
    }

    private HttpClient CreateClient()
    {
        var client = _httpClientFactory.CreateClient("SapServiceLayer");
        client.BaseAddress = new Uri(_baseUrl.TrimEnd('/') + "/");
        return client;
    }

    private async Task<(string Cookie, int TimeoutMinutes)> LoginAsync(
        string username, string password, CancellationToken ct)
    {
        var client = CreateClient();

        var payload = new SapLoginRequest { CompanyDB = _companyDb, UserName = username, Password = password };

        // SAP Service Layer's Apache front-end returns a 500 HTML page when the
        // Content-Type carries "charset=utf-8" (what PostAsJsonAsync sends), and
        // can also choke on Expect: 100-continue. curl/Insomnia work because they
        // send neither — so we build the request by hand to match them exactly:
        // Content-Type "application/json" with no charset, and ExpectContinue off.
        var jsonBody = System.Text.Json.JsonSerializer.Serialize(payload, SapJsonOptions);
        using var content = new StringContent(jsonBody);
        content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/json");

        using var request = new HttpRequestMessage(HttpMethod.Post, "Login") { Content = content };
        request.Headers.ExpectContinue = false;

        var response = await client.SendAsync(request, ct);

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
        var cookie = routeId != null ? $"{b1Session}; {routeId}" : b1Session;

        var timeoutMinutes = body?.SessionTimeout > 0 ? body.SessionTimeout : 30;
        return (cookie, timeoutMinutes);
    }
}
