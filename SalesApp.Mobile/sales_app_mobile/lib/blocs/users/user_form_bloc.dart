import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/app_user.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/user_repository.dart';

part 'user_form_event.dart';
part 'user_form_state.dart';

/// Backs both the "new user" and "edit user" forms, plus the reset-password
/// dialog on the edit screen. One-shot submit, same shape as SubmitOrderBloc.
class UserFormBloc extends Bloc<UserFormEvent, UserFormState> {
  final UserRepository _repository;

  UserFormBloc(this._repository) : super(const UserFormState()) {
    on<UserFormCreateSubmitted>(_onCreate);
    on<UserFormUpdateSubmitted>(_onUpdate);
    on<UserFormPasswordResetSubmitted>(_onResetPassword);
  }

  Future<void> _onCreate(
    UserFormCreateSubmitted event,
    Emitter<UserFormState> emit,
  ) async {
    if (state.status == UserFormStatus.submitting) return;
    emit(state.copyWith(status: UserFormStatus.submitting));
    try {
      final user = await _repository.create(
        username: event.username,
        password: event.password,
        salesEmployeeCode: event.salesEmployeeCode,
        roleId: event.roleId,
        isActive: event.isActive,
      );
      emit(state.copyWith(status: UserFormStatus.success, result: user));
    } on ApiException catch (e) {
      emit(state.copyWith(status: UserFormStatus.failure, error: e.message));
    }
  }

  Future<void> _onUpdate(
    UserFormUpdateSubmitted event,
    Emitter<UserFormState> emit,
  ) async {
    if (state.status == UserFormStatus.submitting) return;
    emit(state.copyWith(status: UserFormStatus.submitting));
    try {
      final user = await _repository.update(
        event.id,
        salesEmployeeCode: event.salesEmployeeCode,
        roleId: event.roleId,
        isActive: event.isActive,
      );
      emit(state.copyWith(status: UserFormStatus.success, result: user));
    } on ApiException catch (e) {
      emit(state.copyWith(status: UserFormStatus.failure, error: e.message));
    }
  }

  Future<void> _onResetPassword(
    UserFormPasswordResetSubmitted event,
    Emitter<UserFormState> emit,
  ) async {
    if (state.status == UserFormStatus.submitting) return;
    emit(state.copyWith(status: UserFormStatus.submitting));
    try {
      await _repository.resetPassword(event.id, event.newPassword);
      emit(state.copyWith(status: UserFormStatus.passwordResetSuccess));
    } on ApiException catch (e) {
      emit(state.copyWith(status: UserFormStatus.failure, error: e.message));
    }
  }
}
