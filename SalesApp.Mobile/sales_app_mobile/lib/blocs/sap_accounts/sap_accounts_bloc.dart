import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/sap_account.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/sap_account_repository.dart';

part 'sap_accounts_event.dart';
part 'sap_accounts_state.dart';

/// Loads the list for the admin "Usuarios SAP" screen. Create/edit/delete
/// live in SapAccountFormBloc — this one is read-only.
class SapAccountsBloc extends Bloc<SapAccountsEvent, SapAccountsState> {
  final SapAccountRepository _repository;

  SapAccountsBloc(this._repository) : super(const SapAccountsState()) {
    on<SapAccountsStarted>((event, emit) => _load(emit));
    on<SapAccountsRefreshed>((event, emit) => _load(emit));
  }

  Future<void> _load(Emitter<SapAccountsState> emit) async {
    emit(state.copyWith(status: SapAccountsStatus.loading));
    try {
      final accounts = await _repository.list();
      emit(state.copyWith(
          status: SapAccountsStatus.success, accounts: accounts));
    } on ApiException catch (e) {
      emit(state.copyWith(status: SapAccountsStatus.failure, error: e.message));
    }
  }
}
