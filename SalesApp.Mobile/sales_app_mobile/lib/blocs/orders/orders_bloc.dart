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
