import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/order.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/order_repository.dart';

part 'orders_event.dart';
part 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final OrderRepository _repository;

  OrdersBloc(this._repository) : super(const OrdersState()) {
    on<OrdersStarted>((event, emit) => _load(state.filter, emit));
    on<OrdersFilterChanged>((event, emit) => _load(event.filter, emit));
    on<OrdersRefreshed>((event, emit) => _load(state.filter, emit));
    on<OrdersGenerateRequested>(_onGenerate);
  }

  Future<void> _onGenerate(
      OrdersGenerateRequested event, Emitter<OrdersState> emit) async {
    if (state.generatingId != null) return; // one at a time
    emit(state.copyWith(generatingId: event.draftId));
    final Order order;
    try {
      order = await _repository.generate(event.draftId);
    } on ApiException catch (e) {
      emit(state.copyWith(clearGenerating: true, generateError: e.message));
      return;
    }
    // The draft became an Order: reload so it shows as a regular order. A
    // failed reload must not read as a failed generation — keep the old list.
    List<Order>? orders;
    try {
      orders = await _repository.listByStatus(state.filter.api);
    } on ApiException {
      orders = null;
    }
    emit(state.copyWith(
      orders: orders,
      clearGenerating: true,
      generated: order,
    ));
  }

  Future<void> _load(OrderStatusFilter filter, Emitter<OrdersState> emit) async {
    emit(state.copyWith(filter: filter, status: OrdersStatus.loading));
    try {
      final orders = await _repository.listByStatus(filter.api);
      emit(state.copyWith(
        filter: filter,
        status: OrdersStatus.success,
        orders: orders,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        filter: filter,
        status: OrdersStatus.failure,
        orders: const [],
        error: e.message,
      ));
    }
  }
}
