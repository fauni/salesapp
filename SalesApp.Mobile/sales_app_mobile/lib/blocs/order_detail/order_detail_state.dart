part of 'order_detail_bloc.dart';

enum OrderDetailStatus { loading, success, failure }

class OrderDetailState extends Equatable {
  final OrderDetailStatus status;
  final Order? order;
  final String? error;

  // "Cerrar pedido" in-flight tracking, kept separate from status/error above
  // so a close failure doesn't blow away the already-loaded order.
  final bool closing;
  final String? closeError;

  const OrderDetailState({
    this.status = OrderDetailStatus.loading,
    this.order,
    this.error,
    this.closing = false,
    this.closeError,
  });

  OrderDetailState copyWith({
    OrderDetailStatus? status,
    Order? order,
    String? error,
    bool? closing,
    String? closeError,
  }) {
    return OrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      error: error,
      closing: closing ?? this.closing,
      closeError: closeError,
    );
  }

  @override
  List<Object?> get props => [status, order, error, closing, closeError];
}
