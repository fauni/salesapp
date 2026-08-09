import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../core/jwt.dart';
import '../storage/token_storage.dart';

/// Attaches the Bearer token to every request and keeps it fresh.
///
/// RF-04: the backend has no refresh token — /auth/refresh only works while the
/// current JWT is still valid. So we refresh PROACTIVELY (before expiry) inside
/// [onRequest], never relying on a 401 to trigger it. A real 401 means the
/// session is gone: we clear the token and notify the app to log out.
class AuthInterceptor extends Interceptor {
  final TokenStorage _storage;
  final Dio _refreshDio; // interceptor-free client, only for /auth/refresh
  final Future<void> Function() onSessionExpired;

  bool _refreshing = false;

  AuthInterceptor({
    required TokenStorage storage,
    required Dio refreshDio,
    required this.onSessionExpired,
  })  : _storage = storage,
        _refreshDio = refreshDio;

  static bool _isAuthEndpoint(String path) =>
      path.contains('/api/auth/login') || path.contains('/api/auth/refresh');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // login/refresh carry their own auth (or none) — don't touch them.
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    var token = await _storage.readToken();

    // Proactively renew while still valid but close to expiring.
    if (token != null &&
        !Jwt.isExpired(token) &&
        Jwt.expiresWithin(token, AppConfig.refreshThreshold)) {
      token = await _refresh(token) ?? token;
    }

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<String?> _refresh(String currentToken) async {
    if (_refreshing) return null; // avoid concurrent refresh storms
    _refreshing = true;
    try {
      final resp = await _refreshDio.post(
        '/api/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $currentToken'}),
      );
      final newToken = (resp.data as Map)['token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        await _storage.saveToken(newToken);
        return newToken;
      }
    } catch (_) {
      // Refresh failed — keep the old token; if it's truly dead, the next call
      // returns 401 and onError below logs the user out.
    } finally {
      _refreshing = false;
    }
    return null;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final path = err.requestOptions.path;
    if (err.response?.statusCode == 401 && !_isAuthEndpoint(path)) {
      await _storage.clear();
      await onSessionExpired();
    }
    handler.next(err);
  }
}
