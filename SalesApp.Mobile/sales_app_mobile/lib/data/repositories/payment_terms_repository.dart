import 'package:dio/dio.dart';

import '../models/payment_terms.dart';
import '../network/api_error.dart';

class PaymentTermsRepository {
  final Dio _dio;

  PaymentTermsRepository({required Dio dio}) : _dio = dio;

  /// GET /api/paymentterms — all SAP payment terms groups (for the
  /// order-summary picker).
  Future<List<PaymentTerms>> listAll() async {
    try {
      final resp = await _dio.get('/api/paymentterms');
      final data = resp.data as List<dynamic>;
      return data
          .map((e) =>
              PaymentTerms.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
