import 'package:dio/dio.dart';

import '../models/login_response.dart';
import '../storage/token_storage.dart';

/// Thrown for an expected auth failure (e.g. wrong credentials) so the Bloc can
/// show a friendly message instead of a raw DioException.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  final Dio _dio;
  final TokenStorage _storage;

  AuthRepository({required Dio dio, required TokenStorage storage})
      : _dio = dio,
        _storage = storage;

  /// POST /api/auth/login — stores the JWT on success.
  Future<LoginResponse> login(String username, String password) async {
    try {
      final resp = await _dio.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );
      final login = LoginResponse.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
      await _storage.saveToken(login.token);
      return login;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Usuario o contraseña inválidos');
      }
      throw AuthException(_networkMessage(e));
    }
  }

  Future<String?> currentToken() => _storage.readToken();

  Future<void> logout() => _storage.clear();

  String _networkMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar con el servidor';
    }
    // Surface the backend's { message, sap } when present.
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Error inesperado (${e.response?.statusCode ?? 'sin respuesta'})';
  }
}
