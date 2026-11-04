import 'package:dio/dio.dart';

import '../models/app_user.dart';
import '../network/api_error.dart';

/// Admin-only CRUD for SalesApp users (`/api/users`). All calls 403 for
/// non-Administrator callers — the backend enforces this, the UI just hides
/// the entry point (see app_drawer.dart).
class UserRepository {
  final Dio _dio;

  UserRepository({required Dio dio}) : _dio = dio;

  /// GET /api/users
  Future<List<AppUser>> list() async {
    try {
      final resp = await _dio.get('/api/users');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// GET /api/users/{id}
  Future<AppUser> getById(int id) async {
    try {
      final resp = await _dio.get('/api/users/$id');
      return AppUser.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /api/users
  Future<AppUser> create({
    required String username,
    required String password,
    String? salesEmployeeCode,
    int? sapAccountId,
    required int roleId,
    bool isActive = true,
  }) async {
    try {
      final resp = await _dio.post('/api/users', data: {
        'username': username,
        'password': password,
        'salesEmployeeCode': ?salesEmployeeCode,
        'sapAccountId': ?sapAccountId,
        'roleId': roleId,
        'isActive': isActive,
      });
      return AppUser.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// PUT /api/users/{id} — Username isn't editable (see backend UsersController).
  /// [sapAccountId] null = technical account (unassigns any current one).
  Future<AppUser> update(
    int id, {
    String? salesEmployeeCode,
    int? sapAccountId,
    required int roleId,
    required bool isActive,
  }) async {
    try {
      final resp = await _dio.put('/api/users/$id', data: {
        'salesEmployeeCode': ?salesEmployeeCode,
        'sapAccountId': ?sapAccountId,
        'roleId': roleId,
        'isActive': isActive,
      });
      return AppUser.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /api/users/{id}/reset-password
  Future<void> resetPassword(int id, String newPassword) async {
    try {
      await _dio.post('/api/users/$id/reset-password',
          data: {'newPassword': newPassword});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
