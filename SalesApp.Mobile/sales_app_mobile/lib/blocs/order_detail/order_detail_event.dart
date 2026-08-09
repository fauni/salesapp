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

class OrderDetailDuplicateRequested extends OrderDetailEvent {
  const OrderDetailDuplicateRequested();
}
