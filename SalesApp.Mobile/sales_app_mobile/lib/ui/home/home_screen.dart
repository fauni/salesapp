import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/orders/orders_bloc.dart';
import '../../data/models/order.dart';
import '../theme/app_colors.dart';
import '../orders/widgets/order_card.dart';
import '../orders/widgets/status_segmented_control.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/gradient_fab.dart';

/// Home = "Mis pedidos": segmented control (Pendientes/Autorizados/Rechazados),
/// list of order cards, FAB to start a new order.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Mis pedidos',
      floatingActionButton: GradientFab(
        onPressed: () => context.go('/new-order'),
      ),
      body: BlocListener<OrdersBloc, OrdersState>(
        listenWhen: (p, c) =>
            (c.generated != null && p.generated != c.generated) ||
            (c.generateError != null && p.generateError != c.generateError),
        listener: (context, state) {
          final generated = state.generated;
          final message = generated == null
              ? state.generateError!
              : generated.id > 0
                  ? 'Orden de venta #${generated.docNum} generada en SAP'
                  : 'Orden de venta generada en SAP';
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        child: BlocBuilder<OrdersBloc, OrdersState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: StatusSegmentedControl(
                    value: state.filter,
                    onChanged: (f) =>
                        context.read<OrdersBloc>().add(OrdersFilterChanged(f)),
                  ),
                ),
                Expanded(child: _OrdersList(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Confirms, then asks SAP to turn the authorized draft into the real order.
Future<void> _confirmGenerate(BuildContext context, Order order) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Generar orden de venta'),
      content: Text(
          'El borrador #${order.docNum} de ${order.customerName ?? order.customerCode} '
          'ya fue autorizado en SAP. ¿Generar la orden de venta?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Generar'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    context.read<OrdersBloc>().add(OrdersGenerateRequested(order.id));
  }
}

class _OrdersList extends StatelessWidget {
  final OrdersState state;
  const _OrdersList({required this.state});

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<OrdersBloc>();
    bloc.add(const OrdersRefreshed());
    await bloc.stream.firstWhere((s) => s.status != OrdersStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case OrdersStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case OrdersStatus.failure:
        return _Refreshable(
          onRefresh: () => _refresh(context),
          child: _Message(
            icon: Icons.error_outline_rounded,
            title: state.error ?? 'No se pudieron cargar los pedidos',
            actionLabel: 'Reintentar',
            onAction: () => context.read<OrdersBloc>().add(const OrdersRefreshed()),
          ),
        );

      case OrdersStatus.success:
        if (state.orders.isEmpty) {
          return _Refreshable(
            onRefresh: () => _refresh(context),
            child: _Message(
              icon: Icons.inbox_outlined,
              title: 'No hay pedidos ${state.filter.label.toLowerCase()}',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            itemCount: state.orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final order = state.orders[i];
              return OrderCard(
                order: order,
                onTap: () => context.push(order.detailPath),
                onGenerate: order.canGenerate
                    ? () => _confirmGenerate(context, order)
                    : null,
                generating: state.generatingId == order.id,
              );
            },
          ),
        );
    }
  }
}

/// Wraps a single message in a scrollable so pull-to-refresh works on the
/// empty/error states too.
class _Refreshable extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const _Refreshable({required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(child: child),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: AppColors.text3),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.text2),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
