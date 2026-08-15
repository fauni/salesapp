import 'package:dio/dio.dart';

import '../models/branch.dart';
import '../network/api_error.dart';

class BranchRepository {
  final Dio _dio;

  BranchRepository({required Dio dio}) : _dio = dio;

  /// GET /api/branches — all active SAP "Sucursales" (DistributionRules) for
  /// the order-summary picker.
  Future<List<Branch>> listAll() async {
    try {
      final resp = await _dio.get('/api/branches');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => Branch.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
