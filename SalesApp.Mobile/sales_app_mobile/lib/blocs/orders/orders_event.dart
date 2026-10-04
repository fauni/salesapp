part of 'orders_bloc.dart';

sealed class OrdersEvent extends Equatable {
  const OrdersEvent();
  @override
  List<Object?> get props => [];
}

/// Initial load of the default filter.
class OrdersStarted extends OrdersEvent {
  const OrdersStarted();
}

/// User switched the segmented control (Pendientes/Autorizados/Rechazados).
class OrdersFilterChanged extends OrdersEvent {
  final OrderStatusFilter filter;
  const OrdersFilterChanged(this.filter);
  @override
  List<Object?> get props => [filter];
}

/// Pull-to-refresh / retry the current filter.
class OrdersRefreshed extends OrdersEvent {
  const OrdersRefreshed();
}

/// Rep confirmed "Generar orden de venta" on an approved draft.
class OrdersGenerateRequested extends OrdersEvent {
  final int draftId;
  const OrdersGenerateRequested(this.draftId);
  @override
  List<Object?> get props => [draftId];
}
