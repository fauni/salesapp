import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/order.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/order_repository.dart';

part 'order_detail_event.dart';
part 'order_detail_state.dart';

class OrderDetailBloc extends Bloc<OrderDetailEvent, OrderDetailState> {
  final OrderRepository _repository;
  final int orderId;

  /// Order status from the list (pending|approved|rejected) — tells the backend
  /// whether to read the SAP Order or the Draft. Null falls back to Order.
  final String? orderStatus;

  OrderDetailBloc(this._repository, this.orderId, {this.orderStatus})
      : super(const OrderDetailState()) {
    on<OrderDetailStarted>((event, emit) => _load(emit));
    on<OrderDetailRefreshed>((event, emit) => _load(emit));
    on<OrderDetailDuplicateRequested>(_onDuplicate);
  }

  Future<void> _load(Emitter<OrderDetailState> emit) async {
    emit(state.copyWith(status: OrderDetailStatus.loading));
    try {
      final order = await _repository.getById(orderId, status: orderStatus);
      emit(state.copyWith(status: OrderDetailStatus.success, order: order));
    } on ApiException catch (e) {
      emit(state.copyWith(status: OrderDetailStatus.failure, error: e.message));
    }
  }

  Future<void> _onDuplicate(
    OrderDetailDuplicateRequested event,
    Emitter<OrderDetailState> emit,
  ) async {
    if (state.duplicating) return;
    emit(state.copyWith(duplicating: true));
    try {
      final created = await _repository.duplicate(orderId);
      emit(state.copyWith(duplicating: false, duplicated: created));
    } on ApiException catch (e) {
      emit(state.copyWith(duplicating: false, duplicateError: e.message));
    }
  }
}
