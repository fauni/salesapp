part of 'order_detail_bloc.dart';

sealed class OrderDetailEvent extends Equatable {
  const OrderDetailEvent();
  @override
  List<Object?> get props => [];
}

class OrderDetailStarted extends OrderDetailEvent {
  const OrderDetailStarted();
}

class OrderDetailRefreshed extends OrderDetailEvent {
  const OrderDetailRefreshed();
}

/// "Cerrar pedido" confirmed by the rep. Only valid for approved orders — the
/// screen gates the button so this is never fired for pending/rejected drafts.
class OrderDetailCloseRequested extends OrderDetailEvent {
  const OrderDetailCloseRequested();
}
