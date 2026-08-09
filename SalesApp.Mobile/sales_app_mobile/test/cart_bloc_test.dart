import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/cart/cart_bloc.dart';
import 'package:sales_app_mobile/data/models/cart_line.dart';
import 'package:sales_app_mobile/data/models/customer.dart';

CartLine _line(String code, double qty, {double? price}) => CartLine(
      itemCode: code,
      itemName: 'Item $code',
      quantity: qty,
      unitPrice: price,
    );

void main() {
  test('saving lines adds, replaces by item code, and totals subtotals',
      () async {
    final bloc = CartBloc();
    bloc.add(const CartCustomerSet(Customer(code: 'C1', name: 'Cliente 1')));
    bloc.add(CartLineSaved(_line('A', 2, price: 10)));
    bloc.add(CartLineSaved(_line('B', 1, price: 5)));
    await pumpEventQueue();

    expect(bloc.state.count, 2);
    expect(bloc.state.total, 25); // 2*10 + 1*5
    expect(bloc.state.customer?.code, 'C1');

    // Saving the same item code replaces the line.
    bloc.add(CartLineSaved(_line('A', 5, price: 10)));
    await pumpEventQueue();
    expect(bloc.state.count, 2);
    expect(bloc.state.lineFor('A')?.quantity, 5);
    expect(bloc.state.total, 55); // 5*10 + 1*5

    bloc.add(const CartLineRemoved('A'));
    await pumpEventQueue();
    expect(bloc.state.count, 1);
    expect(bloc.state.lineFor('A'), isNull);
    await bloc.close();
  });

  test('clear keeps the customer but drops the lines', () async {
    final bloc = CartBloc();
    bloc.add(const CartCustomerSet(Customer(code: 'C1', name: 'Cliente 1')));
    bloc.add(CartLineSaved(_line('A', 1)));
    await pumpEventQueue();
    expect(bloc.state.count, 1);

    bloc.add(const CartCleared());
    await pumpEventQueue();
    expect(bloc.state.isEmpty, isTrue);
    expect(bloc.state.customer?.code, 'C1');
    await bloc.close();
  });
}
