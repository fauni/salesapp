import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../config/app_config.dart';

/// Builds preconfigured [Dio] instances pointing at the SalesApp backend.
class ApiClient {
  /// Creates a Dio with the base URL, timeouts and (optionally) self-signed
  /// certificate trust. No interceptors are attached here — callers add them,
  /// which lets us build a separate interceptor-free client for token refresh.
  static Dio createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        contentType: 'application/json',
      ),
    );

    if (AppConfig.allowSelfSignedCert) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        // Internal-network trust downgrade (self-signed backend/SAP). Do NOT
        // use for public-internet hosts.
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }

    return dio;
  }
}
