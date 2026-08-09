import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/blocs/auth/auth_bloc.dart';
import 'package:sales_app_mobile/data/models/login_response.dart';
import 'package:sales_app_mobile/data/repositories/auth_repository.dart';
import 'package:sales_app_mobile/data/storage/token_storage.dart';

class _FakeAuthRepo extends AuthRepository {
  String? storedToken;
  final Future<LoginResponse> Function()? onLogin;

  _FakeAuthRepo({this.onLogin}) : super(dio: Dio(), storage: TokenStorage());

  @override
  Future<LoginResponse> login(String username, String password) =>
      onLogin != null ? onLogin!() : throw const AuthException('no login');

  @override
  Future<String?> currentToken() async => storedToken;

  @override
  Future<void> logout() async => storedToken = null;
}

void main() {
  test('login success authenticates with user info', () async {
    final repo = _FakeAuthRepo(
      onLogin: () async => const LoginResponse(
        token: 't',
        username: 'rep1',
        salesEmployeeCode: '7',
        roles: ['Salesperson'],
      ),
    );
    final bloc = AuthBloc(repo)..add(const AuthLoginRequested('rep1', 'pw'));

    await bloc.stream.firstWhere((s) => s.status == AuthStatus.authenticated);

    expect(bloc.state.username, 'rep1');
    expect(bloc.state.salesEmployeeCode, '7');
    expect(bloc.state.roles, ['Salesperson']);
    await bloc.close();
  });

  test('login failure stays unauthenticated with an error', () async {
    final repo = _FakeAuthRepo(
      onLogin: () async => throw const AuthException('Usuario o contraseña inválidos'),
    );
    final bloc = AuthBloc(repo)..add(const AuthLoginRequested('x', 'y'));

    await bloc.stream.firstWhere((s) => s.status == AuthStatus.unauthenticated);

    expect(bloc.state.error, 'Usuario o contraseña inválidos');
    await bloc.close();
  });

  test('check with no stored token starts unauthenticated', () async {
    final bloc = AuthBloc(_FakeAuthRepo())..add(const AuthCheckRequested());

    await bloc.stream.firstWhere((s) => s.status == AuthStatus.unauthenticated);

    expect(bloc.state.isAuthenticated, isFalse);
    await bloc.close();
  });

  test('logout returns to unauthenticated', () async {
    final repo = _FakeAuthRepo(
      onLogin: () async =>
          const LoginResponse(token: 't', username: 'rep1'),
    );
    final bloc = AuthBloc(repo)..add(const AuthLoginRequested('rep1', 'pw'));
    await bloc.stream.firstWhere((s) => s.status == AuthStatus.authenticated);

    bloc.add(const AuthLogoutRequested());
    await bloc.stream.firstWhere((s) => s.status == AuthStatus.unauthenticated);

    expect(bloc.state.isAuthenticated, isFalse);
    await bloc.close();
  });
}
