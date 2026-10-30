import 'package:dio/dio.dart';

import '../models/managed_warehouse.dart';
import '../network/api_error.dart';

/// Admin-only management of the global allowed-warehouses list
/// (`/api/warehouses`). All calls 403 for non-Administrator callers — the
/// backend enforces this, the UI just hides the entry point (see app_drawer.dart).
class WarehouseRepository {
  final Dio _dio;

  WarehouseRepository({required Dio dio}) : _dio = dio;

  /// GET /api/warehouses — every SAP warehouse with its `allowed` flag.
  Future<List<ManagedWarehouse>> list() async {
    try {
      final resp = await _dio.get('/api/warehouses');
      return _parse(resp.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// PUT /api/warehouses/allowed — replaces the whole allowed list.
  Future<List<ManagedWarehouse>> saveAllowed(Iterable<String> codes) async {
    try {
      final resp = await _dio.put('/api/warehouses/allowed',
          data: {'codes': codes.toList()});
      return _parse(resp.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  List<ManagedWarehouse> _parse(dynamic data) => (data as List<dynamic>)
      .map((e) => ManagedWarehouse.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
