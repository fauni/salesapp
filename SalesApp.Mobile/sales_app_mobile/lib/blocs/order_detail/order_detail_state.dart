part of 'order_detail_bloc.dart';

enum OrderDetailStatus { loading, success, failure }

class OrderDetailState extends Equatable {
  final OrderDetailStatus status;
  final Order? order;
  final String? error;

  /// True while a duplicate request is in flight.
  final bool duplicating;

  /// Set once when a duplicate succeeds, so the UI can navigate to the new
  /// order. Transient — carries the freshly created order.
  final Order? duplicated;

  /// Set when a duplicate fails, for a one-off snackbar.
  final String? duplicateError;

  const OrderDetailState({
    this.status = OrderDetailStatus.loading,
    this.order,
    this.error,
    this.duplicating = false,
    this.duplicated,
    this.duplicateError,
  });

  OrderDetailState copyWith({
    OrderDetailStatus? status,
    Order? order,
    String? error,
    bool? duplicating,
    Order? duplicated,
    String? duplicateError,
  }) {
    return OrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      error: error,
      duplicating: duplicating ?? this.duplicating,
      duplicated: duplicated,
      duplicateError: duplicateError,
    );
  }

  @override
  List<Object?> get props =>
      [status, order, error, duplicating, duplicated, duplicateError];
}
