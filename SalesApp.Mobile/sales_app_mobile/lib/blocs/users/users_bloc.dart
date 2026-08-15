import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/app_user.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/user_repository.dart';

part 'users_event.dart';
part 'users_state.dart';

/// Loads the user list for the admin "Usuarios" screen. Create/edit/reset
/// live in UserFormBloc — this one is read-only.
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final UserRepository _repository;

  UsersBloc(this._repository) : super(const UsersState()) {
    on<UsersStarted>((event, emit) => _load(emit));
    on<UsersRefreshed>((event, emit) => _load(emit));
  }

  Future<void> _load(Emitter<UsersState> emit) async {
    emit(state.copyWith(status: UsersStatus.loading));
    try {
      final users = await _repository.list();
      emit(state.copyWith(status: UsersStatus.success, users: users));
    } on ApiException catch (e) {
      emit(state.copyWith(status: UsersStatus.failure, error: e.message));
    }
  }
}
