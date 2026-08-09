import 'package:go_router/go_router.dart';

import 'blocs/auth/auth_bloc.dart';
import 'core/go_router_refresh_stream.dart';
import 'ui/home/home_screen.dart';
import 'ui/login/login_screen.dart';
import 'ui/splash/splash_screen.dart';

/// Auth-gated router. `redirect` reads the current AuthBloc state and keeps the
/// user on the right screen; `refreshListenable` re-runs it on every state
/// change (login, logout, session expiry).
GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;

      // Still restoring the session on startup: stay on the splash.
      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      final authenticated = status == AuthStatus.authenticated;

      if (!authenticated) {
        return loc == '/login' ? null : '/login';
      }

      // Authenticated but sitting on splash/login: go home.
      if (loc == '/splash' || loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    ],
  );
}
