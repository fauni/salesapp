import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/orders/orders_bloc.dart';
import 'package:sales_app_mobile/data/models/order.dart';
import 'package:sales_app_mobile/data/network/api_error.dart';
import 'package:sales_app_mobile/data/repositories/order_repository.dart';

class _FakeRepo extends OrderRepository {
  final Future<Order> Function(int id) onGenerate;
  final Future<List<Order>> Function() onList;
  _FakeRepo({required this.onGenerate, required this.onList})
      : super(dio: Dio());

  @override
  Future<Order> generate(int draftId) => onGenerate(draftId);

  @override
  Future<List<Order>> listByStatus(String status) => onList();
}

const _draft = Order(
  id: 7,
  docNum: 70,
  customerCode: 'C1',
  status: 'approved',
  isDraft: true,
  docTotal: 0,
);

const _created = Order(
  id: 900,
  docNum: 5001,
  customerCode: 'C1',
  status: 'approved',
  docTotal: 0,
);

void main() {
  test('only approved drafts can be generated', () {
    expect(_draft.canGenerate, isTrue);
    expect(_created.canGenerate, isFalse);
    const pendingDraft = Order(
        id: 1,
        docNum: 1,
        customerCode: 'C1',
        status: 'pending',
        isDraft: true,
        docTotal: 0);
    expect(pendingDraft.canGenerate, isFalse);
  });

  test('detail path tells the backend to read Drafts', () {
    expect(_draft.detailPath, '/orders/7?status=approved&draft=true');
    expect(_created.detailPath, '/orders/900?status=approved');
  });

  test('generating replaces the draft with the new order', () async {
    final bloc = OrdersBloc(_FakeRepo(
      onGenerate: (id) async => _created,
      onList: () async => [_created],
    ))
      ..add(const OrdersGenerateRequested(7));

    await bloc.stream.firstWhere((s) => s.generated != null);

    expect(bloc.state.generated?.docNum, 5001);
    expect(bloc.state.generatingId, isNull);
    expect(bloc.state.orders.single.isDraft, isFalse);
    await bloc.close();
  });

  test('a SAP error surfaces and keeps the list', () async {
    final bloc = OrdersBloc(_FakeRepo(
      onGenerate: (id) async =>
          throw const ApiException('This order is not authorized in SAP'),
      onList: () async => [_draft],
    ))
      ..add(const OrdersGenerateRequested(7));

    await bloc.stream.firstWhere((s) => s.generateError != null);

    expect(bloc.state.generateError, contains('not authorized'));
    expect(bloc.state.generatingId, isNull);
    await bloc.close();
  });

  test('a failed reload after generating still reports success', () async {
    final bloc = OrdersBloc(_FakeRepo(
      onGenerate: (id) async => _created,
      onList: () async => throw const ApiException('timeout'),
    ))
      ..add(const OrdersGenerateRequested(7));

    await bloc.stream.firstWhere((s) => s.generated != null);

    expect(bloc.state.generateError, isNull);
    await bloc.close();
  });
}
