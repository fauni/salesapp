import 'package:dio/dio.dart';

import '../models/sales_person.dart';
import '../models/sales_series.dart';
import '../network/api_error.dart';

class SalespersonRepository {
  final Dio _dio;

  SalespersonRepository({required Dio dio}) : _dio = dio;

  /// GET /api/salespersons — all active SAP salespersons (for the order-summary
  /// picker).
  Future<List<SalesPerson>> listAll() async {
    try {
      final resp = await _dio.get('/api/salespersons');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => SalesPerson.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// GET /api/salespersons/{code}/series — the numbering series this user may
  /// use. `code` must match the caller's JWT salesEmployeeCode (backend 403s
  /// otherwise).
  Future<List<SalesSeries>> getSeries(String code) async {
    try {
      final resp = await _dio.get('/api/salespersons/$code/series');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => SalesSeries.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
