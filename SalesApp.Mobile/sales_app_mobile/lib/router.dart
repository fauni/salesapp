import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/cart/cart_bloc.dart';
import 'blocs/contacts/contacts_bloc.dart';
import 'blocs/customers/customers_bloc.dart';
import 'blocs/items/items_bloc.dart';
import 'blocs/order_detail/order_detail_bloc.dart';
import 'blocs/orders/orders_bloc.dart';
import 'blocs/series/series_bloc.dart';
import 'blocs/submit_order/submit_order_bloc.dart';
import 'core/go_router_refresh_stream.dart';
import 'core/page_transition.dart';
import 'data/models/customer.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/item_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/salesperson_repository.dart';
import 'ui/customers/client_picker_screen.dart';
import 'ui/customers/customer_detail_screen.dart';
import 'ui/customers/customers_screen.dart';
import 'ui/home/home_screen.dart';
import 'ui/items/item_catalog_screen.dart';
import 'ui/login/login_screen.dart';
import 'ui/orders/order_detail_screen.dart';
import 'ui/orders/order_summary_screen.dart';
import 'ui/profile/profile_screen.dart';
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
        pageBuilder: (context, _) => appPage(
          BlocProvider(
            create: (context) =>
                OrdersBloc(context.read<OrderRepository>())
                  ..add(const OrdersStarted()),
            child: const HomeScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return appPage(
            BlocProvider(
              create: (context) =>
                  OrderDetailBloc(context.read<OrderRepository>(), id)
                    ..add(const OrderDetailStarted()),
              child: const OrderDetailScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/new-order',
        pageBuilder: (context, _) => appPage(
          BlocProvider(
            create: (context) =>
                CustomersBloc(context.read<CustomerRepository>())
                  ..add(const CustomersSearchChanged('')),
            child: const ClientPickerScreen(),
          ),
        ),
      ),
      // The new-order building flow (catalog + summary) shares one CartBloc.
      ShellRoute(
        builder: (context, state, child) => BlocProvider(
          create: (_) => CartBloc(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/new-order/catalog',
            // No customer (cold deep-link) => bounce back to the client picker.
            redirect: (context, state) =>
                state.extra is Customer ? null : '/new-order',
            pageBuilder: (context, state) {
              final customer = state.extra as Customer;
              return appPage(
                BlocProvider(
                  create: (context) =>
                      ItemsBloc(context.read<ItemRepository>())
                        ..add(const ItemsSearchChanged('')),
                  child: ItemCatalogScreen(customer: customer),
                ),
              );
            },
          ),
          GoRoute(
            path: '/new-order/summary',
            pageBuilder: (context, state) {
              final code = context.read<AuthBloc>().state.salesEmployeeCode;
              return appPage(
                MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (context) => SeriesBloc(
                        context.read<SalespersonRepository>(), code)
                        ..add(const SeriesLoadRequested()),
                    ),
                    BlocProvider(
                      create: (context) =>
                          SubmitOrderBloc(context.read<OrderRepository>()),
                    ),
                  ],
                  child: const OrderSummaryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/customers',
        pageBuilder: (context, _) => appPage(
          BlocProvider(
            create: (context) =>
                CustomersBloc(context.read<CustomerRepository>())
                  ..add(const CustomersSearchChanged('')),
            child: const CustomersScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/customers/:code',
        pageBuilder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          final customer = state.extra as Customer?;
          return appPage(
            BlocProvider(
              create: (context) =>
                  ContactsBloc(context.read<CustomerRepository>(), code)
                    ..add(const ContactsStarted()),
              child: CustomerDetailScreen(code: code, customer: customer),
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, _) => appPage(const ProfileScreen()),
      ),
    ],
  );
}
