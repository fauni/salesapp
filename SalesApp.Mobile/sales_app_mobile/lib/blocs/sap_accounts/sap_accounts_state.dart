part of 'sap_accounts_bloc.dart';

enum SapAccountsStatus { loading, success, failure }

class SapAccountsState extends Equatable {
  final SapAccountsStatus status;
  final List<SapAccount> accounts;
  final String? error;

  const SapAccountsState({
    this.status = SapAccountsStatus.loading,
    this.accounts = const [],
    this.error,
  });

  SapAccountsState copyWith({
    SapAccountsStatus? status,
    List<SapAccount>? accounts,
    String? error,
  }) {
    return SapAccountsState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, accounts, error];
}
