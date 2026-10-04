import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/cart/cart_bloc.dart';
import 'blocs/contacts/contacts_bloc.dart';
import 'blocs/customer_detail/customer_detail_bloc.dart';
import 'blocs/customers/customers_bloc.dart';
import 'blocs/items/items_bloc.dart';
import 'blocs/order_detail/order_detail_bloc.dart';
import 'blocs/orders/orders_bloc.dart';
import 'blocs/submit_order/submit_order_bloc.dart';
import 'blocs/users/user_form_bloc.dart';
import 'blocs/users/users_bloc.dart';
import 'core/go_router_refresh_stream.dart';
import 'core/page_transition.dart';
import 'data/models/app_user.dart';
import 'data/models/customer.dart';
import 'data/models/order.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/item_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/user_repository.dart';
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
import 'ui/users/user_form_screen.dart';
import 'ui/users/users_screen.dart';
import 'ui/widgets/home_shell.dart';

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
      // Bottom nav: Mis pedidos / Clientes / Mi perfil. Each branch keeps its
      // own navigation stack (StatefulShellRoute), so e.g. drilling into a
      // customer detail and switching tabs away/back preserves that stack.
      // Coexists with the side drawer (see HomeShell / app_drawer.dart).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
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
          ]),
          StatefulShellBranch(routes: [
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
              routes: [
                GoRoute(
                  path: ':code',
                  pageBuilder: (context, state) {
                    final code = state.pathParameters['code'] ?? '';
                    final customer = state.extra as Customer?;
                    return appPage(
                      MultiBlocProvider(
                        providers: [
                          BlocProvider(
                            create: (context) => CustomerDetailBloc(
                                context.read<CustomerRepository>(), code)
                              ..add(const CustomerDetailStarted()),
                          ),
                          BlocProvider(
                            create: (context) => ContactsBloc(
                                context.read<CustomerRepository>(), code)
                              ..add(const ContactsStarted()),
                          ),
                        ],
                        child:
                            CustomerDetailScreen(code: code, customer: customer),
                      ),
                    );
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (_, _) => appPage(const ProfileScreen()),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/orders/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          // Approved orders are SAP Orders; pending/rejected are Drafts. The
          // list passes the status so the detail reads the right entity
          // (plus draft=true for approved drafts not yet generated).
          final status = state.uri.queryParameters['status'];
          final isDraft = state.uri.queryParameters['draft'] == 'true';
          return appPage(
            BlocProvider(
              create: (context) =>
                  OrderDetailBloc(context.read<OrderRepository>(), id,
                      orderStatus: status, isDraft: isDraft)
                    ..add(const OrderDetailStarted()),
              child: const OrderDetailScreen(),
            ),
          );
        },
      ),
      // "Duplicar pedido": opens the summary precharged from an existing order
      // (customer + lines), ready to edit before creating a NEW order. Its own
      // CartBloc — must NOT share the one from the /new-order ShellRoute below,
      // or the two flows would clobber each other's in-progress cart. Shell so
      // "Agregar más ítems" can push its own catalog sharing this same
      // CartBloc/SubmitOrderBloc (mirrors the /new-order catalog+summary shell).
      // See _DuplicateOrderShell for why extra needs to be captured once.
      ShellRoute(
        builder: (context, state, child) =>
            _DuplicateOrderShell(extra: state.extra, child: child),
        routes: [
          GoRoute(
            path: '/orders/:id/duplicate',
            pageBuilder: (context, state) {
              final order = context.read<Order>();
              return appPage(OrderSummaryScreen(sourceOrder: order));
            },
          ),
          GoRoute(
            path: '/orders/:id/duplicate/catalog',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'];
              final customer = context.read<CartBloc>().state.customer!;
              return appPage(
                BlocProvider(
                  create: (context) =>
                      ItemsBloc(context.read<ItemRepository>())
                        ..add(const ItemsSearchChanged('')),
                  child: ItemCatalogScreen(
                    customer: customer,
                    summaryRoute: '/orders/$id/duplicate',
                  ),
                ),
              );
            },
          ),
        ],
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
              return appPage(
                BlocProvider(
                  create: (context) =>
                      SubmitOrderBloc(context.read<OrderRepository>()),
                  child: const OrderSummaryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      // Admin-only "Usuarios" (see app_drawer.dart — item hidden for non-
      // Administrators; the backend also enforces this via [Authorize(Roles=
      // "Administrator")] on UsersController, so a direct deep link 403s).
      GoRoute(
        path: '/users',
        pageBuilder: (context, _) => appPage(
          BlocProvider(
            create: (context) =>
                UsersBloc(context.read<UserRepository>())
                  ..add(const UsersStarted()),
            child: const UsersScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/users/new',
        pageBuilder: (context, _) => appPage(
          BlocProvider(
            create: (context) => UserFormBloc(context.read<UserRepository>()),
            child: const UserFormScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/users/:id/edit',
        pageBuilder: (context, state) {
          final user = state.extra as AppUser?;
          return appPage(
            BlocProvider(
              create: (context) => UserFormBloc(context.read<UserRepository>()),
              child: UserFormScreen(existing: user),
            ),
          );
        },
      ),
    ],
  );
}

/// Providers shell for the "Duplicar pedido" flow (summary + its own
/// catalog). [extra] is the source [Order], only actually passed on the
/// initial push — captured once in [initState] so CartBloc/SubmitOrderBloc/
/// the Order itself stay the same instance while navigating between the
/// flow's nested routes (which push back into this shell without re-sending
/// extra).
class _DuplicateOrderShell extends StatefulWidget {
  final Object? extra;
  final Widget child;

  const _DuplicateOrderShell({required this.extra, required this.child});

  @override
  State<_DuplicateOrderShell> createState() => _DuplicateOrderShellState();
}

class _DuplicateOrderShellState extends State<_DuplicateOrderShell> {
  late final Order _order = widget.extra as Order;
  late final CartBloc _cartBloc = CartBloc()
    ..add(CartInitializedFromOrder(_order));

  @override
  void dispose() {
    _cartBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cartBloc),
        BlocProvider(
          create: (context) => SubmitOrderBloc(context.read<OrderRepository>()),
        ),
      ],
      child: RepositoryProvider<Order>.value(
        value: _order,
        child: widget.child,
      ),
    );
  }
}
