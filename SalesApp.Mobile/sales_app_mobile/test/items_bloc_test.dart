import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/items/items_bloc.dart';
import 'package:sales_app_mobile/data/models/item.dart';
import 'package:sales_app_mobile/data/models/items_page.dart';
import 'package:sales_app_mobile/data/repositories/item_repository.dart';

class _FakeItemRepo extends ItemRepository {
  final ItemsPage Function(String query, int page) handler;
  _FakeItemRepo(this.handler) : super(dio: Dio());

  @override
  Future<ItemsPage> search({String query = '', int page = 1, int pageSize = 20}) async =>
      handler(query, page);
}

Item _item(String code) => Item(code: code, name: 'Item $code');

void main() {
  test('search loads the first page and computes hasMore', () async {
    final repo = _FakeItemRepo((q, p) => ItemsPage(
          items: [_item('A'), _item('B')],
          page: p,
          pageSize: 20,
          totalCount: 3,
        ));
    final bloc = ItemsBloc(repo)..add(const ItemsSearchChanged(''));

    await bloc.stream.firstWhere((s) => s.status == ItemsStatus.success);

    expect(bloc.state.items.length, 2);
    expect(bloc.state.hasMore, isTrue);
    await bloc.close();
  });

  test('next page appends and stops when complete', () async {
    final repo = _FakeItemRepo((q, p) => p == 1
        ? ItemsPage(
            items: [_item('A'), _item('B')],
            page: 1,
            pageSize: 20,
            totalCount: 3)
        : ItemsPage(
            items: [_item('C')], page: 2, pageSize: 20, totalCount: 3));
    final bloc = ItemsBloc(repo)..add(const ItemsSearchChanged(''));
    await bloc.stream.firstWhere((s) => s.status == ItemsStatus.success);

    bloc.add(const ItemsNextPageRequested());
    await bloc.stream.firstWhere((s) => s.items.length == 3);

    expect(bloc.state.hasMore, isFalse);
    expect(bloc.state.items.map((i) => i.code), ['A', 'B', 'C']);
    await bloc.close();
  });
}
