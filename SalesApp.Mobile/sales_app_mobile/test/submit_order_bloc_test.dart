import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/submit_order/submit_order_bloc.dart';
import 'package:sales_app_mobile/data/models/cart_line.dart';
import 'package:sales_app_mobile/data/models/order.dart';
import 'package:sales_app_mobile/data/network/api_error.dart';
import 'package:sales_app_mobile/data/repositories/order_repository.dart';

class _FakeRepo extends OrderRepository {
  final Future<Order> Function() onCreate;
  _FakeRepo(this.onCreate) : super(dio: Dio());

  @override
  Future<Order> create({
    required String customerCode,
    int? series,
    DateTime? dueDate,
    String? comments,
    required List<CartLine> lines,
  }) =>
      onCreate();
}

const _event = OrderSubmitted(
  customerCode: 'C1',
  lines: [CartLine(itemCode: 'A', itemName: 'Item A', quantity: 1)],
);

Order _order() => const Order(
      id: 42,
      docNum: 1001,
      customerCode: 'C1',
      status: 'approved',
      docTotal: 0,
    );

void main() {
  test('successful submit exposes the created order', () async {
    final bloc = SubmitOrderBloc(_FakeRepo(() async => _order()))
      ..add(_event);

    await bloc.stream.firstWhere((s) => s.status == SubmitStatus.success);

    expect(bloc.state.created?.id, 42);
    await bloc.close();
  });

  test('a SAP rejection surfaces the message', () async {
    final bloc = SubmitOrderBloc(
        _FakeRepo(() async => throw const ApiException('SAP rechazó el pedido')))
      ..add(_event);

    await bloc.stream.firstWhere((s) => s.status == SubmitStatus.failure);

    expect(bloc.state.error, 'SAP rechazó el pedido');
    await bloc.close();
  });
}
