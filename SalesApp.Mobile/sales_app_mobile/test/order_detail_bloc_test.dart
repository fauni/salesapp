import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/order_detail/order_detail_bloc.dart';
import 'package:sales_app_mobile/data/models/order.dart';
import 'package:sales_app_mobile/data/network/api_error.dart';
import 'package:sales_app_mobile/data/repositories/order_repository.dart';

class _FakeRepo extends OrderRepository {
  final Future<Order> Function(int id) onGet;
  final Future<Order> Function(int id)? onClose;
  _FakeRepo({required this.onGet, this.onClose}) : super(dio: Dio());

  @override
  Future<Order> getById(int id, {String? status, bool isDraft = false}) =>
      onGet(id);

  @override
  Future<Order> close(int id) => onClose!(id);
}

Order _order(int id, {int? docNum, bool isClosed = false}) => Order(
      id: id,
      docNum: docNum ?? id,
      customerCode: 'C1',
      status: 'approved',
      isClosed: isClosed,
      docTotal: 250,
    );

void main() {
  test('OrderDetailStarted loads the order', () async {
    final repo = _FakeRepo(onGet: (id) async => _order(id, docNum: 500));
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());

    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.success);

    expect(bloc.state.order?.id, 7);
    expect(bloc.state.order?.docNum, 500);
    await bloc.close();
  });

  test('a load error moves to failure', () async {
    final repo =
        _FakeRepo(onGet: (_) async => throw const ApiException('not found'));
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());

    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.failure);

    expect(bloc.state.error, 'not found');
    await bloc.close();
  });

  test('OrderDetailCloseRequested closes the order and refreshes in place',
      () async {
    final repo = _FakeRepo(
      onGet: (id) async => _order(id),
      onClose: (id) async => _order(id, isClosed: true),
    );
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());
    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.success);

    bloc.add(const OrderDetailCloseRequested());
    await bloc.stream.firstWhere((s) => !s.closing);

    expect(bloc.state.order?.isClosed, true);
    expect(bloc.state.status, OrderDetailStatus.success);
    expect(bloc.state.closeError, isNull);
    await bloc.close();
  });

  test('a close error keeps the loaded order and sets closeError', () async {
    final repo = _FakeRepo(
      onGet: (id) async => _order(id),
      onClose: (_) async => throw const ApiException('SAP rejected the close'),
    );
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());
    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.success);

    bloc.add(const OrderDetailCloseRequested());
    await bloc.stream.firstWhere((s) => !s.closing);

    expect(bloc.state.closeError, 'SAP rejected the close');
    expect(bloc.state.order?.isClosed, false);
    await bloc.close();
  });
}
