import 'package:dio/dio.dart';

import '../models/item.dart';
import '../models/item_unit_of_measure.dart';
import '../models/items_page.dart';
import '../network/api_error.dart';

class ItemRepository {
  final Dio _dio;

  ItemRepository({required Dio dio}) : _dio = dio;

  /// GET /api/items?search=&page=&pageSize=
  ///
  /// `priceList` is intentionally NOT sent (decision 2026-08-09): prices are not
  /// resolved by list; the catalog shows stock. `pageSize` is capped at 20 by
  /// the backend.
  Future<ItemsPage> search({
    String query = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final resp = await _dio.get('/api/items', queryParameters: {
        if (query.isNotEmpty) 'search': query,
        'page': page,
        'pageSize': pageSize,
      });
      final map = Map<String, dynamic>.from(resp.data as Map);
      final items = (map['items'] as List<dynamic>)
          .map((e) => Item.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return ItemsPage(
        items: items,
        page: (map['page'] as num?)?.toInt() ?? page,
        pageSize: (map['pageSize'] as num?)?.toInt() ?? pageSize,
        totalCount: (map['totalCount'] as num?)?.toInt() ?? items.length,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// GET /api/items/{code}/units-of-measure
  ///
  /// Sales UoM options for one item, resolved on demand (called when the
  /// line-config sheet opens, not in the catalog listing).
  Future<List<ItemUnitOfMeasure>> unitsOfMeasure(String itemCode) async {
    try {
      final resp = await _dio.get(
          '/api/items/${Uri.encodeComponent(itemCode)}/units-of-measure');
      return (resp.data as List<dynamic>)
          .map((e) =>
              ItemUnitOfMeasure.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
