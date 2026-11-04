using SalesApp.Core.Interfaces;

namespace SalesApp.Api.Auth;

// Reads the caller's SapAccount from the JWT ("sapAccountId" claim, set by
// TokenService). No HTTP request / no claim -> null = technical account.
// The claim is fixed at login: reassigning a user's SAP account applies on
// their next login/refresh, same as SalesEmployeeCode.
public class SapAccountContext : ISapAccountContext
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public SapAccountContext(IHttpContextAccessor httpContextAccessor) =>
        _httpContextAccessor = httpContextAccessor;

    public int? SapAccountId =>
        int.TryParse(_httpContextAccessor.HttpContext?.User.FindFirst("sapAccountId")?.Value, out var id)
            ? id
            : null;
}
