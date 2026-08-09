import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/order_detail/order_detail_bloc.dart';
import 'package:sales_app_mobile/data/models/order.dart';
import 'package:sales_app_mobile/data/network/api_error.dart';
import 'package:sales_app_mobile/data/repositories/order_repository.dart';

class _FakeRepo extends OrderRepository {
  final Future<Order> Function(int id) onGet;
  final Future<Order> Function(int id) onDuplicate;
  _FakeRepo({required this.onGet, required this.onDuplicate})
      : super(dio: Dio());

  @override
  Future<Order> getById(int id) => onGet(id);

  @override
  Future<Order> duplicate(int id) => onDuplicate(id);
}

Order _order(int id, {int? docNum}) => Order(
      id: id,
      docNum: docNum ?? id,
      customerCode: 'C1',
      status: 'approved',
      docTotal: 250,
    );

void main() {
  test('OrderDetailStarted loads the order', () async {
    final repo = _FakeRepo(
      onGet: (id) async => _order(id, docNum: 500),
      onDuplicate: (_) async => _order(0),
    );
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());

    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.success);

    expect(bloc.state.order?.id, 7);
    expect(bloc.state.order?.docNum, 500);
    await bloc.close();
  });

  test('a load error moves to failure', () async {
    final repo = _FakeRepo(
      onGet: (_) async => throw const ApiException('not found'),
      onDuplicate: (_) async => _order(0),
    );
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());

    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.failure);

    expect(bloc.state.error, 'not found');
    await bloc.close();
  });

  test('duplicate success exposes the new order', () async {
    final repo = _FakeRepo(
      onGet: (id) async => _order(id),
      onDuplicate: (_) async => _order(99, docNum: 900),
    );
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());
    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.success);

    bloc.add(const OrderDetailDuplicateRequested());
    await bloc.stream.firstWhere((s) => s.duplicated != null);

    expect(bloc.state.duplicated?.id, 99);
    expect(bloc.state.duplicating, isFalse);
    await bloc.close();
  });

  test('duplicate error surfaces a message', () async {
    final repo = _FakeRepo(
      onGet: (id) async => _order(id),
      onDuplicate: (_) async => throw const ApiException('sap rejected'),
    );
    final bloc = OrderDetailBloc(repo, 7)..add(const OrderDetailStarted());
    await bloc.stream.firstWhere((s) => s.status == OrderDetailStatus.success);

    bloc.add(const OrderDetailDuplicateRequested());
    await bloc.stream.firstWhere((s) => s.duplicateError != null);

    expect(bloc.state.duplicateError, 'sap rejected');
    expect(bloc.state.duplicating, isFalse);
    await bloc.close();
  });
}
