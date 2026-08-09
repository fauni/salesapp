part of 'orders_bloc.dart';

/// The three order states surfaced by the app (map 1:1 to the backend
/// `?status=` values via `.api`).
enum OrderStatusFilter {
  pending,
  approved,
  rejected;

  String get api => name; // 'pending' | 'approved' | 'rejected'

  String get label => switch (this) {
        OrderStatusFilter.pending => 'Pendientes',
        OrderStatusFilter.approved => 'Autorizados',
        OrderStatusFilter.rejected => 'Rechazados',
      };
}

enum OrdersStatus { loading, success, failure }

class OrdersState extends Equatable {
  final OrderStatusFilter filter;
  final OrdersStatus status;
  final List<Order> orders;
  final String? error;

  const OrdersState({
    this.filter = OrderStatusFilter.pending,
    this.status = OrdersStatus.loading,
    this.orders = const [],
    this.error,
  });

  OrdersState copyWith({
    OrderStatusFilter? filter,
    OrdersStatus? status,
    List<Order>? orders,
    String? error,
  }) {
    return OrdersState(
      filter: filter ?? this.filter,
      status: status ?? this.status,
      orders: orders ?? this.orders,
      error: error,
    );
  }

  @override
  List<Object?> get props => [filter, status, orders, error];
}
