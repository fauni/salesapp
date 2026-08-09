import 'package:flutter/material.dart';

import 'app.dart';
import 'blocs/auth/auth_bloc.dart';
import 'data/network/api_client.dart';
import 'data/network/auth_interceptor.dart';
import 'data/repositories/auth_repository.dart';
import 'data/storage/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Dependency wiring (manual DI; keep it simple) ---
  final storage = TokenStorage();

  // Two clients: the main one carries the auth interceptor; `refreshDio` is
  // interceptor-free so the proactive-refresh call can't recurse into itself.
  final dio = ApiClient.createDio();
  final refreshDio = ApiClient.createDio();

  final authRepository = AuthRepository(dio: dio, storage: storage);
  final authBloc = AuthBloc(authRepository)..add(const AuthCheckRequested());

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      refreshDio: refreshDio,
      onSessionExpired: () async => authBloc.add(const AuthSessionExpired()),
    ),
  );

  runApp(SalesApp(authBloc: authBloc));
}
