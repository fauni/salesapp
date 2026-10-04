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

  /// Approved drafts (authorized, not generated) also live in Drafts.
  final bool isDraft;

  OrderDetailBloc(this._repository, this.orderId,
      {this.orderStatus, this.isDraft = false})
      : super(const OrderDetailState()) {
    on<OrderDetailStarted>((event, emit) => _load(emit));
    on<OrderDetailRefreshed>((event, emit) => _load(emit));
    on<OrderDetailCloseRequested>(_onClose);
  }

  Future<void> _load(Emitter<OrderDetailState> emit) async {
    emit(state.copyWith(status: OrderDetailStatus.loading));
    try {
      final order = await _repository.getById(orderId,
          status: orderStatus, isDraft: isDraft);
      emit(state.copyWith(status: OrderDetailStatus.success, order: order));
    } on ApiException catch (e) {
      emit(state.copyWith(status: OrderDetailStatus.failure, error: e.message));
    }
  }

  Future<void> _onClose(
      OrderDetailCloseRequested event, Emitter<OrderDetailState> emit) async {
    emit(state.copyWith(closing: true, closeError: null));
    try {
      final order = await _repository.close(orderId);
      emit(state.copyWith(
        status: OrderDetailStatus.success,
        order: order,
        closing: false,
      ));
    } on ApiException catch (e) {
      // Keep the currently-loaded order — only the close attempt failed.
      emit(state.copyWith(closing: false, closeError: e.message));
    }
  }
}
