import 'package:dio/dio.dart';

import '../models/project.dart';
import '../network/api_error.dart';

class ProjectRepository {
  final Dio _dio;

  ProjectRepository({required Dio dio}) : _dio = dio;

  /// GET /api/projects — all active SAP projects (for the order-summary picker).
  Future<List<Project>> listAll() async {
    try {
      final resp = await _dio.get('/api/projects');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
