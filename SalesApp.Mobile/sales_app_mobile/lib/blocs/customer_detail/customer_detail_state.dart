part of 'customer_detail_bloc.dart';

enum CustomerDetailStatus { loading, success, failure }

class CustomerDetailState extends Equatable {
  final CustomerDetailStatus status;
  final CustomerDetail? detail;
  final String? error;

  const CustomerDetailState({
    this.status = CustomerDetailStatus.loading,
    this.detail,
    this.error,
  });

  CustomerDetailState copyWith({
    CustomerDetailStatus? status,
    CustomerDetail? detail,
    String? error,
  }) {
    return CustomerDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, detail, error];
}
