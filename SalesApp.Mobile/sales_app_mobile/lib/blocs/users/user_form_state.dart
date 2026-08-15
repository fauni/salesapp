part of 'user_form_bloc.dart';

enum UserFormStatus { idle, submitting, success, passwordResetSuccess, failure }

class UserFormState extends Equatable {
  final UserFormStatus status;
  final AppUser? result;
  final String? error;

  const UserFormState({
    this.status = UserFormStatus.idle,
    this.result,
    this.error,
  });

  UserFormState copyWith({
    UserFormStatus? status,
    AppUser? result,
    String? error,
  }) {
    return UserFormState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, result, error];
}
