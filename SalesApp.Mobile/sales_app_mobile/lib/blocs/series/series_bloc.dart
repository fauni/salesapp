import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/sales_series.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/salesperson_repository.dart';

part 'series_event.dart';
part 'series_state.dart';

/// Loads the numbering series the current user may use. If the user isn't linked
/// to a SAP salesperson (no code), there's nothing to load.
class SeriesBloc extends Bloc<SeriesEvent, SeriesState> {
  final SalespersonRepository _repository;
  final String? salesEmployeeCode;

  SeriesBloc(this._repository, this.salesEmployeeCode)
      : super(const SeriesState()) {
    on<SeriesLoadRequested>((event, emit) => _load(emit));
  }

  Future<void> _load(Emitter<SeriesState> emit) async {
    final code = salesEmployeeCode;
    if (code == null || code.isEmpty) {
      emit(state.copyWith(status: SeriesStatus.success, series: const []));
      return;
    }
    emit(state.copyWith(status: SeriesStatus.loading));
    try {
      final series = await _repository.getSeries(code);
      emit(state.copyWith(status: SeriesStatus.success, series: series));
    } on ApiException catch (e) {
      emit(state.copyWith(status: SeriesStatus.failure, error: e.message));
    }
  }
}
