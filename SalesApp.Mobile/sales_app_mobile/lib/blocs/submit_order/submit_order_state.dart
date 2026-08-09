part of 'submit_order_bloc.dart';

enum SubmitStatus { idle, submitting, success, failure }

class SubmitOrderState extends Equatable {
  final SubmitStatus status;
  final Order? created;
  final String? error;

  const SubmitOrderState({
    this.status = SubmitStatus.idle,
    this.created,
    this.error,
  });

  SubmitOrderState copyWith({
    SubmitStatus? status,
    Order? created,
    String? error,
  }) {
    return SubmitOrderState(
      status: status ?? this.status,
      created: created ?? this.created,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, created, error];
}
