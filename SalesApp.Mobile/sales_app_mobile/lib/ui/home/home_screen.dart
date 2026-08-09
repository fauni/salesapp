import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/gradient_fab.dart';

/// Home = "Mis pedidos". The segmented control + order-card list arrive in
/// Etapa 1; for now this proves the shell (drawer + FAB) and session state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;

    return AppScaffold(
      title: 'Mis pedidos',
      floatingActionButton: GradientFab(
        onPressed: () => context.go('/new-order'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded,
                size: 48, color: AppColors.text3),
            const SizedBox(height: 12),
            Text('Listado de pedidos (Etapa 1)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Sesión: ${state.username ?? '-'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.text2)),
          ],
        ),
      ),
    );
  }
}
