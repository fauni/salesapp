/// App-wide configuration. Values are compile-time overridable with
/// `--dart-define`, e.g. `--dart-define=API_BASE_URL=https://sales.client.local`.
class AppConfig {
  /// Base URL of the SalesApp backend.
  ///
  /// Default targets the Android emulator, which reaches the host machine at
  /// 10.0.2.2 (localhost inside the emulator is the emulator itself). For a
  /// real device or the client's on-prem server, override via --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7047',
  );

  /// Accept self-signed certificates. The backend/SAP live on the client's
  /// internal network with self-signed certs; this is an accepted trade-off
  /// there. NEVER enable for a host on the public internet.
  static const bool allowSelfSignedCert = bool.fromEnvironment(
    'ALLOW_SELF_SIGNED',
    defaultValue: true,
  );

  /// The backend has no refresh token: /auth/refresh only works while the JWT
  /// is still valid. So we renew proactively when it's within this window of
  /// expiring, instead of waiting for a 401 (which would force a full re-login).
  static const Duration refreshThreshold = Duration(minutes: 5);
}
