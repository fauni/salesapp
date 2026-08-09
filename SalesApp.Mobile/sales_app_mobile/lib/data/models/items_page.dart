import 'item.dart';

/// One page of the paginated `/api/items` response (backend `PagedResult`).
class ItemsPage {
  final List<Item> items;
  final int page;
  final int pageSize;
  final int totalCount;

  const ItemsPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });
}
