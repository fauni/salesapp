import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'blocs/auth/auth_bloc.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/item_repository.dart';
import 'data/repositories/order_repository.dart';
import 'router.dart';
import 'ui/theme/app_theme.dart';

class SalesApp extends StatefulWidget {
  final AuthBloc authBloc;
  final Dio dio;
  const SalesApp({super.key, required this.authBloc, required this.dio});

  @override
  State<SalesApp> createState() => _SalesAppState();
}

class _SalesAppState extends State<SalesApp> {
  late final GoRouter _router = buildRouter(widget.authBloc);

  @override
  void dispose() {
    widget.authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<OrderRepository>(
          create: (_) => OrderRepository(dio: widget.dio),
        ),
        RepositoryProvider<CustomerRepository>(
          create: (_) => CustomerRepository(dio: widget.dio),
        ),
        RepositoryProvider<ItemRepository>(
          create: (_) => ItemRepository(dio: widget.dio),
        ),
      ],
      child: BlocProvider.value(
        value: widget.authBloc,
        child: MaterialApp.router(
          title: 'SalesApp',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          routerConfig: _router,
        ),
      ),
    );
  }
}
