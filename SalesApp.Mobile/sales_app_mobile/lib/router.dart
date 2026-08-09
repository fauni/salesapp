import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'blocs/auth/auth_bloc.dart';
import 'core/go_router_refresh_stream.dart';
import 'core/page_transition.dart';
import 'ui/common/placeholder_screen.dart';
import 'ui/home/home_screen.dart';
import 'ui/login/login_screen.dart';
import 'ui/splash/splash_screen.dart';

/// Auth-gated router. `redirect` reads the current AuthBloc state and keeps the
/// user on the right screen; `refreshListenable` re-runs it on every state
/// change (login, logout, session expiry). Screen transitions use the DESIGN.md
/// fade + slide-up motion (see [appPage]).
GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;

      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      final authenticated = status == AuthStatus.authenticated;

      if (!authenticated) {
        return loc == '/login' ? null : '/login';
      }

      if (loc == '/splash' || loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (_, _) => appPage(const LoginScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (_, _) => appPage(const HomeScreen()),
      ),
      GoRoute(
        path: '/new-order',
        pageBuilder: (_, _) => appPage(const PlaceholderScreen(
          title: 'Nuevo pedido',
          icon: Icons.add_shopping_cart_rounded,
          stage: 'Etapas 3–5',
        )),
      ),
      GoRoute(
        path: '/customers',
        pageBuilder: (_, _) => appPage(const PlaceholderScreen(
          title: 'Clientes',
          icon: Icons.people_alt_rounded,
          stage: 'Etapa 3',
        )),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, _) => appPage(const PlaceholderScreen(
          title: 'Perfil',
          icon: Icons.person_rounded,
          stage: 'Etapa 6',
        )),
      ),
    ],
  );
}
