import 'package:dio/dio.dart';

import '../models/customer.dart';
import '../network/api_error.dart';

class CustomerRepository {
  final Dio _dio;

  CustomerRepository({required Dio dio}) : _dio = dio;

  /// GET /api/customers?search= — empty search returns the first page.
  Future<List<Customer>> search(String query) async {
    try {
      final resp = await _dio.get(
        '/api/customers',
        queryParameters: query.isEmpty ? null : {'search': query},
      );
      final data = resp.data as List<dynamic>;
      return data
          .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// GET /api/customers/{code}/contacts
  Future<List<CustomerContact>> getContacts(String code) async {
    try {
      final resp = await _dio.get('/api/customers/$code/contacts');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) =>
              CustomerContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
