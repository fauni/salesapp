import 'dart:convert';

/// Minimal JWT reader — decodes the payload to check expiry and pull a few
/// claims. No signature verification (that's the backend's job); we only need
/// `exp` for proactive refresh and name/role/salesEmployeeCode to restore a
/// session on app start.
class Jwt {
  // .NET's ClaimTypes serialize as these schema URIs inside the token.
  static const _nameClaim =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';
  static const _roleClaim =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  static Map<String, dynamic>? _payload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = json.decode(decoded);
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }

  /// Token expiry in UTC, or null if it can't be read.
  static DateTime? expiry(String token) {
    final exp = _payload(token)?['exp'];
    if (exp is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  /// True if the token is already past its expiry (or unreadable).
  static bool isExpired(String token) {
    final e = expiry(token);
    return e == null || !DateTime.now().toUtc().isBefore(e);
  }

  /// True if the token expires within [window] (used to refresh proactively).
  static bool expiresWithin(String token, Duration window) {
    final e = expiry(token);
    if (e == null) return true;
    return DateTime.now().toUtc().add(window).isAfter(e);
  }

  static String? username(String token) => _payload(token)?[_nameClaim] as String?;

  static String? salesEmployeeCode(String token) =>
      _payload(token)?['salesEmployeeCode'] as String?;

  /// Roles claim may be a single string or a list, depending on how many roles.
  static List<String> roles(String token) {
    final raw = _payload(token)?[_roleClaim];
    if (raw is String) return [raw];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }
}
