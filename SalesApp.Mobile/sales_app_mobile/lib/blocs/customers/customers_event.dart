part of 'customers_bloc.dart';

sealed class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

/// Fired on every keystroke; debounced inside the bloc.
class CustomersSearchChanged extends CustomersEvent {
  final String query;
  const CustomersSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}
