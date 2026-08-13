import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/customer.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/customer_repository.dart';

part 'customer_detail_event.dart';
part 'customer_detail_state.dart';

/// Loads the full detail of one customer (by CardCode), including the resolved
/// price-list and payment-terms names. Separate from ContactsBloc so each part
/// of the screen loads (and can retry) independently.
class CustomerDetailBloc
    extends Bloc<CustomerDetailEvent, CustomerDetailState> {
  final CustomerRepository _repository;
  final String customerCode;

  CustomerDetailBloc(this._repository, this.customerCode)
      : super(const CustomerDetailState()) {
    on<CustomerDetailStarted>((event, emit) => _load(emit));
    on<CustomerDetailRefreshed>((event, emit) => _load(emit));
  }

  Future<void> _load(Emitter<CustomerDetailState> emit) async {
    emit(state.copyWith(status: CustomerDetailStatus.loading));
    try {
      final detail = await _repository.getByCode(customerCode);
      emit(state.copyWith(
          status: CustomerDetailStatus.success, detail: detail));
    } on ApiException catch (e) {
      emit(state.copyWith(
          status: CustomerDetailStatus.failure, error: e.message));
    }
  }
}
