part of 'customer_detail_bloc.dart';

sealed class CustomerDetailEvent extends Equatable {
  const CustomerDetailEvent();
  @override
  List<Object?> get props => [];
}

class CustomerDetailStarted extends CustomerDetailEvent {
  const CustomerDetailStarted();
}

class CustomerDetailRefreshed extends CustomerDetailEvent {
  const CustomerDetailRefreshed();
}
