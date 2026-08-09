import 'package:dio/dio.dart';

/// Friendly, user-facing error for any API call. Repositories translate
/// [DioException] into this so Blocs/UI never deal with raw Dio internals.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Maps a Dio failure to an [ApiException], surfacing the backend's
/// `{ message, sap }` shape (from SapExceptionFilter) when present.
ApiException mapDioError(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return const ApiException('No se pudo conectar con el servidor');
  }

  final data = e.response?.data;
  if (data is Map && data['message'] is String) {
    final message = data['message'] as String;
    final sap = data['sap'];
    if (sap is String && sap.isNotEmpty) {
      return ApiException('$message: $sap');
    }
    return ApiException(message);
  }

  return ApiException('Error inesperado (${e.response?.statusCode ?? 'sin respuesta'})');
}
