import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';

/// Placeholder landing screen for an authenticated user. The real feature
/// screens (customers, items, orders) come in the next milestones — this just
/// proves login/session/logout work end to end.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SalesApp'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            Text('Sesión iniciada',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Usuario: ${state.username ?? '-'}'),
            Text('Vendedor SAP: ${state.salesEmployeeCode ?? '-'}'),
            Text('Roles: ${state.roles.isEmpty ? '-' : state.roles.join(', ')}'),
          ],
        ),
      ),
    );
  }
}
