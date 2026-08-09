import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../data/models/customer.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/customer_repository.dart';

part 'customers_event.dart';
part 'customers_state.dart';

/// Debounce keystrokes so we don't hit the backend on every character, and
/// cancel any in-flight search when a newer query arrives (switchMap).
EventTransformer<E> _debounceRestart<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomerRepository _repository;

  CustomersBloc(this._repository) : super(const CustomersState()) {
    on<CustomersSearchChanged>(
      _onSearch,
      transformer: _debounceRestart(const Duration(milliseconds: 350)),
    );
  }

  Future<void> _onSearch(
    CustomersSearchChanged event,
    Emitter<CustomersState> emit,
  ) async {
    final query = event.query.trim();
    emit(state.copyWith(query: query, status: CustomersStatus.loading));
    try {
      final customers = await _repository.search(query);
      emit(state.copyWith(
        status: CustomersStatus.success,
        customers: customers,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: CustomersStatus.failure,
        customers: const [],
        error: e.message,
      ));
    }
  }
}
