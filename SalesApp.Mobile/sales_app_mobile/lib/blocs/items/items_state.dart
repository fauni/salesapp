part of 'items_bloc.dart';

enum ItemsStatus { loading, success, failure }

class ItemsState extends Equatable {
  final String query;
  final ItemsStatus status;
  final List<Item> items;
  final int page;
  final int totalCount;
  final bool loadingMore;
  final String? error;

  const ItemsState({
    this.query = '',
    this.status = ItemsStatus.loading,
    this.items = const [],
    this.page = 1,
    this.totalCount = 0,
    this.loadingMore = false,
    this.error,
  });

  bool get hasMore => items.length < totalCount;

  ItemsState copyWith({
    String? query,
    ItemsStatus? status,
    List<Item>? items,
    int? page,
    int? totalCount,
    bool? loadingMore,
    String? error,
  }) {
    return ItemsState(
      query: query ?? this.query,
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      totalCount: totalCount ?? this.totalCount,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [query, status, items, page, totalCount, loadingMore, error];
}
