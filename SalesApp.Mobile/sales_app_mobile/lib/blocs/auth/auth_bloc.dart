import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/jwt.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc(this._repository) : super(const AuthState.unknown()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = await _repository.currentToken();
    if (token == null || Jwt.isExpired(token)) {
      // Nothing stored, or expired and unusable (no refresh token to fall back
      // on) — start unauthenticated.
      if (token != null) await _repository.logout();
      emit(const AuthState.unauthenticated());
      return;
    }
    emit(AuthState.authenticated(
      username: Jwt.username(token) ?? '',
      salesEmployeeCode: Jwt.salesEmployeeCode(token),
      roles: Jwt.roles(token),
    ));
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.authenticating());
    try {
      final login = await _repository.login(event.username, event.password);
      emit(AuthState.authenticated(
        username: login.username,
        salesEmployeeCode: login.salesEmployeeCode,
        roles: login.roles,
      ));
    } on AuthException catch (e) {
      emit(AuthState.unauthenticated(error: e.message));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthState.unauthenticated());
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    // Token already cleared by the interceptor; just reflect it in state.
    emit(const AuthState.unauthenticated(error: 'La sesión expiró'));
  }
}
