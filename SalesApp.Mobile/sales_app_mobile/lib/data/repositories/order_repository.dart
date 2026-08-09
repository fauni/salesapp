import 'package:dio/dio.dart';

import '../models/cart_line.dart';
import '../models/order.dart';
import '../network/api_error.dart';

class OrderRepository {
  final Dio _dio;

  OrderRepository({required Dio dio}) : _dio = dio;

  /// GET /api/orders?status=pending|approved|rejected
  Future<List<Order>> listByStatus(String status) async {
    try {
      final resp = await _dio.get(
        '/api/orders',
        queryParameters: {'status': status},
      );
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// GET /api/orders/{id}
  Future<Order> getById(int id) async {
    try {
      final resp = await _dio.get('/api/orders/$id');
      return Order.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /api/orders/{id}/duplicate — returns the newly created order.
  Future<Order> duplicate(int id) async {
    try {
      final resp = await _dio.post('/api/orders/$id/duplicate');
      return Order.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /api/orders — creates a sales order (RF-06..RF-10). SalesPersonCode is
  /// omitted so the backend fills it from the caller's JWT. Null line fields are
  /// dropped so SAP applies its own defaults (e.g. UoM, price from list).
  Future<Order> create({
    required String customerCode,
    int? series,
    DateTime? dueDate,
    String? comments,
    required List<CartLine> lines,
  }) async {
    try {
      final body = <String, dynamic>{
        'customerCode': customerCode,
        'series': ?series,
        'dueDate': ?dueDate?.toIso8601String(),
        if (comments != null && comments.isNotEmpty) 'comments': comments,
        'lines': [
          for (final l in lines)
            <String, dynamic>{
              'itemCode': l.itemCode,
              'quantity': l.quantity,
              'salesUnitOfMeasure': ?l.salesUnitOfMeasure,
              'unitPrice': ?l.unitPrice,
              'warehouseCode': ?l.warehouseCode,
            },
        ],
      };
      final resp = await _dio.post('/api/orders', data: body);
      return Order.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
