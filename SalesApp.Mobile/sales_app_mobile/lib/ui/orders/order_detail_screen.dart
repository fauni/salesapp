import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/order_detail/order_detail_bloc.dart';
import '../../core/format.dart';
import '../../data/models/order.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_card.dart';
import 'widgets/order_status_badge.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderDetailBloc, OrderDetailState>(
      listenWhen: (p, c) => p.closeError != c.closeError && c.closeError != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.closeError!)));
      },
      child: BlocBuilder<OrderDetailBloc, OrderDetailState>(
        builder: (context, state) {
          final title = state.order != null
              ? 'Pedido #${state.order!.docNum}'
              : 'Pedido';
          return AppScaffold(
            title: title,
            onBack: () => context.pop(),
            body: switch (state.status) {
              OrderDetailStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              OrderDetailStatus.failure => _Failure(
                  message: state.error ?? 'No se pudo cargar el pedido',
                  onRetry: () => context
                      .read<OrderDetailBloc>()
                      .add(const OrderDetailRefreshed()),
                ),
              OrderDetailStatus.success => _Content(state: state),
            },
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final OrderDetailState state;
  const _Content({required this.state});

  @override
  Widget build(BuildContext context) {
    final order = state.order!;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<OrderDetailBloc>();
              bloc.add(const OrderDetailRefreshed());
              await bloc.stream
                  .firstWhere((s) => s.status != OrderDetailStatus.loading);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
              Row(
                children: [
                  OrderStatusBadge(status: order.status),
                  if (order.isClosed) ...[
                    const SizedBox(width: 8),
                    const _ClosedChip(),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Datos del pedido',
                child: Column(
                  children: [
                    _InfoRow('Fecha', formatDate(order.docDate)),
                    _InfoRow('Entrega', formatDate(order.dueDate)),
                    _InfoRow(
                        'Vendedor',
                        order.salesPersonName ??
                            order.salesPersonCode?.toString() ??
                            '-'),
                    if ((order.comments ?? '').isNotEmpty)
                      _InfoRow('Comentarios', order.comments!),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Cliente',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName ?? order.customerCode,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text1,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(order.customerCode,
                        style: GoogleFonts.inter(
                            color: AppColors.text2, fontSize: 13)),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.lineSoft),
                    const SizedBox(height: 6),
                    _InfoRow('Cond. de pago',
                        order.paymentTermsGroupName ?? 'No especificada'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Ítems (${order.itemCount})',
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < order.lines.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: AppColors.lineSoft),
                      _LineRow(order.lines[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
                _TotalsCard(order: order),
              ],
            ),
          ),
        ),
        _ActionBar(state: state),
      ],
    );
  }
}

/// Small neutral pill next to the status badge for a closed order. Separate
/// from OrderStatusBadge/OrderStatusStyle on purpose — `status` itself stays
/// "approved" (closing isn't an approval-procedure outcome), this is just an
/// extra visual signal.
class _ClosedChip extends StatelessWidget {
  const _ClosedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'CERRADO',
        style: GoogleFonts.plusJakartaSans(
          color: AppColors.text2,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.text1,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final OrderLine line;
  const _LineRow(this.line);

  @override
  Widget build(BuildContext context) {
    final uom = line.salesUnitOfMeasure ?? '';
    final liters = line.quantityInLiters != null
        ? ' (${formatQty(line.quantityInLiters!)} L)'
        : '';
    final priceText =
        line.unitPrice != null ? ' × ${formatMoney(line.unitPrice!)}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.description ?? line.itemCode,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text1,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatQty(line.quantity)} $uom$liters$priceText · ${line.itemCode}',
                  style:
                      GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(line.lineTotal),
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.text1,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final Order order;
  const _TotalsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final subtotal =
        order.lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
    return SectionCard(
      child: Column(
        children: [
          _row('Subtotal', formatMoney(subtotal), bold: false),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.lineSoft),
          const SizedBox(height: 8),
          _row('Total', formatMoney(order.docTotal), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {required bool bold}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: bold ? AppColors.text1 : AppColors.text2,
                fontSize: bold ? 15 : 13)),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.text1,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final OrderDetailState state;
  const _ActionBar({required this.state});

  Future<void> _confirmClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar pedido'),
        content: const Text(
            '¿Seguro que querés cerrar este pedido? No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Cerrar pedido'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<OrderDetailBloc>().add(const OrderDetailCloseRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = state.order!;
    // Only approved (non-draft) orders that aren't already closed can be
    // closed — pending/rejected are Drafts and don't support this SAP action.
    final canClose = order.status == 'approved' && !order.isClosed;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientButton(
                label: 'Duplicar pedido',
                // Opens the order summary precharged with this order's data
                // (customer + lines), so the rep can review/edit before
                // creating a brand-new order. Does not touch this order.
                onPressed: () => context.push(
                  '/orders/${order.id}/duplicate',
                  extra: order,
                ),
              ),
              if (canClose) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        state.closing ? null : () => _confirmClose(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.negative,
                      side: const BorderSide(color: AppColors.negative),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: state.closing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cerrar pedido'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Failure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 44, color: AppColors.text3),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.text2)),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
