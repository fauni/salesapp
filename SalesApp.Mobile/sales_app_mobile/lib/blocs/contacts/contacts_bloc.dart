import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/customer.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/customer_repository.dart';

part 'contacts_event.dart';
part 'contacts_state.dart';

/// Loads the contact people of one customer (by CardCode).
class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final CustomerRepository _repository;
  final String customerCode;

  ContactsBloc(this._repository, this.customerCode)
      : super(const ContactsState()) {
    on<ContactsStarted>((event, emit) => _load(emit));
    on<ContactsRefreshed>((event, emit) => _load(emit));
  }

  Future<void> _load(Emitter<ContactsState> emit) async {
    emit(state.copyWith(status: ContactsStatus.loading));
    try {
      final contacts = await _repository.getContacts(customerCode);
      emit(state.copyWith(status: ContactsStatus.success, contacts: contacts));
    } on ApiException catch (e) {
      emit(state.copyWith(status: ContactsStatus.failure, error: e.message));
    }
  }
}
