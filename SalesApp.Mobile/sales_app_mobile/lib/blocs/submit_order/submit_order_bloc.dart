import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/cart_line.dart';
import '../../data/models/order.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/order_repository.dart';

part 'submit_order_event.dart';
part 'submit_order_state.dart';

/// Submits the built order to SAP (via the backend). No credit validation and
/// no approval flow — SAP owns both.
class SubmitOrderBloc extends Bloc<SubmitOrderEvent, SubmitOrderState> {
  final OrderRepository _repository;

  SubmitOrderBloc(this._repository) : super(const SubmitOrderState()) {
    on<OrderSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    OrderSubmitted event,
    Emitter<SubmitOrderState> emit,
  ) async {
    if (state.status == SubmitStatus.submitting) return;
    emit(state.copyWith(status: SubmitStatus.submitting));
    try {
      final order = await _repository.create(
        customerCode: event.customerCode,
        series: event.series,
        dueDate: event.dueDate,
        comments: event.comments,
        lines: event.lines,
      );
      emit(state.copyWith(status: SubmitStatus.success, created: order));
    } on ApiException catch (e) {
      emit(state.copyWith(status: SubmitStatus.failure, error: e.message));
    }
  }
}
