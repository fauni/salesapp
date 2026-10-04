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

  /// GET /api/orders/{id}?status=&draft=
  ///
  /// `status` (pending|approved|rejected) tells the backend whether to read the
  /// SAP Order or the Draft — pending/rejected orders are Drafts and 404 in
  /// Orders otherwise. `isDraft` is needed for approved drafts (not generated).
  Future<Order> getById(int id, {String? status, bool isDraft = false}) async {
    try {
      final resp = await _dio.get(
        '/api/orders/$id',
        queryParameters: {
          'status': ?status,
          if (isDraft) 'draft': true,
        },
      );
      return Order.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /api/orders/{id}/generate — turns a draft SAP already AUTHORIZED
  /// into the real sales order (SAP's "Add" on an approved draft; not an
  /// approval). Returns the new order (id 0 if SAP created it but the backend
  /// couldn't look it up).
  Future<Order> generate(int draftId) async {
    try {
      final resp = await _dio.post('/api/orders/$draftId/generate');
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

  /// POST /api/orders/{id}/close — closes an approved order in SAP (all lines
  /// -> bost_Close). Not reversible from the app. Returns the refreshed order.
  Future<Order> close(int id) async {
    try {
      final resp = await _dio.post('/api/orders/$id/close');
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
    int? salesPersonCode,
    int? series,
    DateTime? dueDate,
    String? comments,
    int? paymentTermsGroupCode,
    required List<CartLine> lines,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final body = <String, dynamic>{
        'customerCode': customerCode,
        'salesPersonCode': ?salesPersonCode,
        'series': ?series,
        'dueDate': ?dueDate?.toIso8601String(),
        if (comments != null && comments.isNotEmpty) 'comments': comments,
        'paymentTermsGroupCode': ?paymentTermsGroupCode,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'lines': [
          for (final l in lines)
            <String, dynamic>{
              'itemCode': l.itemCode,
              'quantity': l.quantity,
              'salesUnitOfMeasure': ?l.salesUnitOfMeasure,
              'quantityInLiters': ?l.quantityInLiters,
              'unitPrice': ?l.unitPrice,
              'warehouseCode': ?l.warehouseCode,
              'projectCode': ?l.projectCode,
              'branchCode': ?l.branchCode,
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
