part of 'users_bloc.dart';

sealed class UsersEvent extends Equatable {
  const UsersEvent();
  @override
  List<Object?> get props => [];
}

class UsersStarted extends UsersEvent {
  const UsersStarted();
}

class UsersRefreshed extends UsersEvent {
  const UsersRefreshed();
}
