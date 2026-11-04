part of 'sap_account_form_bloc.dart';

enum SapAccountFormStatus { idle, submitting, success, deleted, failure }

class SapAccountFormState extends Equatable {
  final SapAccountFormStatus status;
  final String? error;

  const SapAccountFormState({
    this.status = SapAccountFormStatus.idle,
    this.error,
  });

  SapAccountFormState copyWith({
    SapAccountFormStatus? status,
    String? error,
  }) {
    return SapAccountFormState(
      status: status ?? this.status,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, error];
}
