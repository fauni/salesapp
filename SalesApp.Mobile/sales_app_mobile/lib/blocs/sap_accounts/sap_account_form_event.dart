part of 'sap_account_form_bloc.dart';

sealed class SapAccountFormEvent extends Equatable {
  const SapAccountFormEvent();
  @override
  List<Object?> get props => [];
}

class SapAccountCreateSubmitted extends SapAccountFormEvent {
  final String name;
  final String username;
  final String password;
  final bool isActive;

  const SapAccountCreateSubmitted({
    required this.name,
    required this.username,
    required this.password,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [name, username, password, isActive];
}

class SapAccountUpdateSubmitted extends SapAccountFormEvent {
  final int id;
  final String name;
  final String username;

  /// Null keeps the current password.
  final String? password;
  final bool isActive;

  const SapAccountUpdateSubmitted({
    required this.id,
    required this.name,
    required this.username,
    this.password,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, name, username, password, isActive];
}

class SapAccountDeleteSubmitted extends SapAccountFormEvent {
  final int id;
  const SapAccountDeleteSubmitted(this.id);

  @override
  List<Object?> get props => [id];
}
