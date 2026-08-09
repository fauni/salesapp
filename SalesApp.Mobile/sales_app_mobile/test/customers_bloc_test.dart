import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/customers/customers_bloc.dart';
import 'package:sales_app_mobile/data/models/customer.dart';
import 'package:sales_app_mobile/data/network/api_error.dart';
import 'package:sales_app_mobile/data/repositories/customer_repository.dart';

class _FakeRepo extends CustomerRepository {
  final Future<List<Customer>> Function(String query) onSearch;
  _FakeRepo(this.onSearch) : super(dio: Dio());

  @override
  Future<List<Customer>> search(String query) => onSearch(query);
}

Customer _c(String code) => Customer(code: code, name: 'Cliente $code');

void main() {
  test('debounces rapid queries into one search of the latest', () async {
    var calls = 0;
    String? lastQuery;
    final repo = _FakeRepo((q) async {
      calls++;
      lastQuery = q;
      return [_c('C1')];
    });
    final bloc = CustomersBloc(repo)
      ..add(const CustomersSearchChanged('a'))
      ..add(const CustomersSearchChanged('ab'))
      ..add(const CustomersSearchChanged('abc'));

    await bloc.stream.firstWhere((s) => s.status == CustomersStatus.success);

    expect(calls, 1);
    expect(lastQuery, 'abc');
    expect(bloc.state.query, 'abc');
    await bloc.close();
  });

  test('a search error moves to failure with a message', () async {
    final repo = _FakeRepo((_) async => throw const ApiException('down'));
    final bloc = CustomersBloc(repo)..add(const CustomersSearchChanged('x'));

    await bloc.stream.firstWhere((s) => s.status == CustomersStatus.failure);

    expect(bloc.state.error, 'down');
    expect(bloc.state.customers, isEmpty);
    await bloc.close();
  });
}
