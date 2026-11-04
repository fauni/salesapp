import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/network/api_error.dart';
import '../../data/repositories/sap_account_repository.dart';

part 'sap_account_form_event.dart';
part 'sap_account_form_state.dart';

/// Backs both the "new" and "edit" SAP account forms, plus delete on the edit
/// screen. One-shot submit, same shape as UserFormBloc.
class SapAccountFormBloc
    extends Bloc<SapAccountFormEvent, SapAccountFormState> {
  final SapAccountRepository _repository;

  SapAccountFormBloc(this._repository) : super(const SapAccountFormState()) {
    on<SapAccountCreateSubmitted>(_onCreate);
    on<SapAccountUpdateSubmitted>(_onUpdate);
    on<SapAccountDeleteSubmitted>(_onDelete);
  }

  Future<void> _onCreate(
    SapAccountCreateSubmitted event,
    Emitter<SapAccountFormState> emit,
  ) async {
    if (state.status == SapAccountFormStatus.submitting) return;
    emit(state.copyWith(status: SapAccountFormStatus.submitting));
    try {
      await _repository.create(
        name: event.name,
        username: event.username,
        password: event.password,
        isActive: event.isActive,
      );
      emit(state.copyWith(status: SapAccountFormStatus.success));
    } on ApiException catch (e) {
      emit(state.copyWith(
          status: SapAccountFormStatus.failure, error: e.message));
    }
  }

  Future<void> _onUpdate(
    SapAccountUpdateSubmitted event,
    Emitter<SapAccountFormState> emit,
  ) async {
    if (state.status == SapAccountFormStatus.submitting) return;
    emit(state.copyWith(status: SapAccountFormStatus.submitting));
    try {
      await _repository.update(
        event.id,
        name: event.name,
        username: event.username,
        password: event.password,
        isActive: event.isActive,
      );
      emit(state.copyWith(status: SapAccountFormStatus.success));
    } on ApiException catch (e) {
      emit(state.copyWith(
          status: SapAccountFormStatus.failure, error: e.message));
    }
  }

  Future<void> _onDelete(
    SapAccountDeleteSubmitted event,
    Emitter<SapAccountFormState> emit,
  ) async {
    if (state.status == SapAccountFormStatus.submitting) return;
    emit(state.copyWith(status: SapAccountFormStatus.submitting));
    try {
      await _repository.delete(event.id);
      emit(state.copyWith(status: SapAccountFormStatus.deleted));
    } on ApiException catch (e) {
      emit(state.copyWith(
          status: SapAccountFormStatus.failure, error: e.message));
    }
  }
}
