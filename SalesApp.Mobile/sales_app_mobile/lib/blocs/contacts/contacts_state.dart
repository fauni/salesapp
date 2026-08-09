part of 'contacts_bloc.dart';

enum ContactsStatus { loading, success, failure }

class ContactsState extends Equatable {
  final ContactsStatus status;
  final List<CustomerContact> contacts;
  final String? error;

  const ContactsState({
    this.status = ContactsStatus.loading,
    this.contacts = const [],
    this.error,
  });

  ContactsState copyWith({
    ContactsStatus? status,
    List<CustomerContact>? contacts,
    String? error,
  }) {
    return ContactsState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, contacts, error];
}
