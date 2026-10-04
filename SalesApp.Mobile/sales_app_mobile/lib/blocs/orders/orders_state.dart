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

  // "Generar orden de venta" tracking — separate from status/error so a
  // failed generation keeps the loaded list on screen.
  /// Draft id currently being generated (button shows a spinner).
  final int? generatingId;

  /// Order created by the last successful generation (one-shot, for the
  /// confirmation snackbar).
  final Order? generated;
  final String? generateError;

  const OrdersState({
    this.filter = OrderStatusFilter.pending,
    this.status = OrdersStatus.loading,
    this.orders = const [],
    this.error,
    this.generatingId,
    this.generated,
    this.generateError,
  });

  /// One-shot fields ([error], [generated], [generateError]) reset unless
  /// passed again; [generatingId] needs [clearGenerating] to be cleared.
  OrdersState copyWith({
    OrderStatusFilter? filter,
    OrdersStatus? status,
    List<Order>? orders,
    String? error,
    int? generatingId,
    bool clearGenerating = false,
    Order? generated,
    String? generateError,
  }) {
    return OrdersState(
      filter: filter ?? this.filter,
      status: status ?? this.status,
      orders: orders ?? this.orders,
      error: error,
      generatingId:
          clearGenerating ? null : generatingId ?? this.generatingId,
      generated: generated,
      generateError: generateError,
    );
  }

  @override
  List<Object?> get props =>
      [filter, status, orders, error, generatingId, generated, generateError];
}
