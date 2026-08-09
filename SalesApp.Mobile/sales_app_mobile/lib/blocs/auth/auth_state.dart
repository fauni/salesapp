part of 'auth_bloc.dart';

enum AuthStatus {
  /// Startup: haven't checked stored token yet (show a splash).
  unknown,

  /// A login/refresh is in flight.
  authenticating,

  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final String? username;
  final String? salesEmployeeCode;
  final List<String> roles;

  /// Last auth error (e.g. bad credentials), for the login screen to show.
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.username,
    this.salesEmployeeCode,
    this.roles = const [],
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;

  const AuthState.unknown() : this();

  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, error: error);

  const AuthState.authenticating() : this(status: AuthStatus.authenticating);

  const AuthState.authenticated({
    required String username,
    String? salesEmployeeCode,
    List<String> roles = const [],
  }) : this(
          status: AuthStatus.authenticated,
          username: username,
          salesEmployeeCode: salesEmployeeCode,
          roles: roles,
        );

  @override
  List<Object?> get props => [status, username, salesEmployeeCode, roles, error];
}
