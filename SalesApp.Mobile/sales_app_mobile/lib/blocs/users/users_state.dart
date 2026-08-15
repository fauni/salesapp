part of 'users_bloc.dart';

enum UsersStatus { loading, success, failure }

class UsersState extends Equatable {
  final UsersStatus status;
  final List<AppUser> users;
  final String? error;

  const UsersState({
    this.status = UsersStatus.loading,
    this.users = const [],
    this.error,
  });

  UsersState copyWith({
    UsersStatus? status,
    List<AppUser>? users,
    String? error,
  }) {
    return UsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, users, error];
}
