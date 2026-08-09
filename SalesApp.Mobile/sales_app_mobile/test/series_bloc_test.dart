import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/series/series_bloc.dart';
import 'package:sales_app_mobile/data/models/sales_series.dart';
import 'package:sales_app_mobile/data/repositories/salesperson_repository.dart';

class _FakeRepo extends SalespersonRepository {
  final Future<List<SalesSeries>> Function(String code) onGet;
  int calls = 0;
  _FakeRepo(this.onGet) : super(dio: Dio());

  @override
  Future<List<SalesSeries>> getSeries(String code) {
    calls++;
    return onGet(code);
  }
}

void main() {
  test('loads the series for the given code', () async {
    final repo = _FakeRepo((code) async =>
        [const SalesSeries(sapSeriesId: 3, sapSeriesName: 'Ventas')]);
    final bloc = SeriesBloc(repo, '7')..add(const SeriesLoadRequested());

    await bloc.stream.firstWhere((s) => s.status == SeriesStatus.success);

    expect(bloc.state.series.single.sapSeriesId, 3);
    expect(repo.calls, 1);
    await bloc.close();
  });

  test('no salesEmployeeCode means no series and no backend call', () async {
    final repo = _FakeRepo((_) async => []);
    final bloc = SeriesBloc(repo, null)..add(const SeriesLoadRequested());

    await bloc.stream.firstWhere((s) => s.status == SeriesStatus.success);

    expect(bloc.state.series, isEmpty);
    expect(repo.calls, 0);
    await bloc.close();
  });
}
