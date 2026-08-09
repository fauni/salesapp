import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/orders/orders_bloc.dart';
import 'package:sales_app_mobile/data/models/order.dart';
import 'package:sales_app_mobile/data/network/api_error.dart';
import 'package:sales_app_mobile/data/repositories/order_repository.dart';

class _FakeRepo extends OrderRepository {
  final Future<List<Order>> Function(String status) handler;
  _FakeRepo(this.handler) : super(dio: Dio());

  @override
  Future<List<Order>> listByStatus(String status) => handler(status);
}

Order _order(int id) => Order(
      id: id,
      docNum: id,
      customerCode: 'C1',
      status: 'pending',
      docTotal: 100,
    );

void main() {
  test('OrdersStarted loads the default (pending) filter', () async {
    final repo = _FakeRepo((status) async => [_order(1), _order(2)]);
    final bloc = OrdersBloc(repo)..add(const OrdersStarted());

    await bloc.stream.firstWhere((s) => s.status == OrdersStatus.success);

    expect(bloc.state.filter, OrderStatusFilter.pending);
    expect(bloc.state.orders.length, 2);
    await bloc.close();
  });

  test('OrdersFilterChanged loads the requested status', () async {
    String? requested;
    final repo = _FakeRepo((status) async {
      requested = status;
      return [_order(9)];
    });
    final bloc = OrdersBloc(repo)
      ..add(const OrdersFilterChanged(OrderStatusFilter.approved));

    await bloc.stream.firstWhere((s) => s.status == OrdersStatus.success);

    expect(requested, 'approved');
    expect(bloc.state.filter, OrderStatusFilter.approved);
    await bloc.close();
  });

  test('a repository error moves the bloc to failure with a message', () async {
    final repo = _FakeRepo((_) async => throw const ApiException('boom'));
    final bloc = OrdersBloc(repo)..add(const OrdersStarted());

    await bloc.stream.firstWhere((s) => s.status == OrdersStatus.failure);

    expect(bloc.state.error, 'boom');
    expect(bloc.state.orders, isEmpty);
    await bloc.close();
  });
}
