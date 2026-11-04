import 'package:dio/dio.dart';

import '../models/sap_account.dart';
import '../network/api_error.dart';

/// Admin-only CRUD for SAP accounts (`/api/sap-accounts`). All calls 403 for
/// non-Administrator callers — the backend enforces this, the UI just hides
/// the entry point (see app_drawer.dart). Saving new credentials makes the
/// backend do a real SAP login first; a failure comes back as SAP's error.
class SapAccountRepository {
  final Dio _dio;

  SapAccountRepository({required Dio dio}) : _dio = dio;

  /// GET /api/sap-accounts
  Future<List<SapAccount>> list() async {
    try {
      final resp = await _dio.get('/api/sap-accounts');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => SapAccount.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /api/sap-accounts
  Future<SapAccount> create({
    required String name,
    required String username,
    required String password,
    bool isActive = true,
  }) async {
    try {
      final resp = await _dio.post('/api/sap-accounts', data: {
        'name': name,
        'username': username,
        'password': password,
        'isActive': isActive,
      });
      return SapAccount.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// PUT /api/sap-accounts/{id} — [password] null keeps the current one.
  Future<SapAccount> update(
    int id, {
    required String name,
    required String username,
    String? password,
    required bool isActive,
  }) async {
    try {
      final resp = await _dio.put('/api/sap-accounts/$id', data: {
        'name': name,
        'username': username,
        'password': ?password,
        'isActive': isActive,
      });
      return SapAccount.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// DELETE /api/sap-accounts/{id} — rejected while users are assigned to it.
  Future<void> delete(int id) async {
    try {
      await _dio.delete('/api/sap-accounts/$id');
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
