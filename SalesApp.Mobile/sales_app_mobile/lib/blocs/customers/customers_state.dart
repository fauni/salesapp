part of 'customers_bloc.dart';

enum CustomersStatus { loading, success, failure }

class CustomersState extends Equatable {
  final String query;
  final CustomersStatus status;
  final List<Customer> customers;
  final String? error;

  const CustomersState({
    this.query = '',
    this.status = CustomersStatus.loading,
    this.customers = const [],
    this.error,
  });

  CustomersState copyWith({
    String? query,
    CustomersStatus? status,
    List<Customer>? customers,
    String? error,
  }) {
    return CustomersState(
      query: query ?? this.query,
      status: status ?? this.status,
      customers: customers ?? this.customers,
      error: error,
    );
  }

  @override
  List<Object?> get props => [query, status, customers, error];
}
