part of 'sap_accounts_bloc.dart';

sealed class SapAccountsEvent extends Equatable {
  const SapAccountsEvent();
  @override
  List<Object?> get props => [];
}

class SapAccountsStarted extends SapAccountsEvent {
  const SapAccountsStarted();
}

class SapAccountsRefreshed extends SapAccountsEvent {
  const SapAccountsRefreshed();
}
