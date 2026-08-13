import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/series/series_bloc.dart';
import '../../blocs/submit_order/submit_order_bloc.dart';
import '../../core/format.dart';
import '../../data/models/cart_line.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/gradient_button.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';

/// New order — step 3: review and confirm. Builds the CreateOrderRequest from
/// the cart + the selected series / due date / comments, and POSTs it.
class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key});

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  int? _seriesId;
  DateTime? _dueDate;
  final _commentsController = TextEditingController();

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  void _submit(CartState cart) {
    context.read<SubmitOrderBloc>().add(OrderSubmitted(
          customerCode: cart.customer!.code,
          series: _seriesId,
          dueDate: _dueDate,
          comments: _commentsController.text.trim(),
          lines: cart.lines,
        ));
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SubmitOrderBloc, SubmitOrderState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == SubmitStatus.success && state.created != null) {
          final order = state.created!;
          final router = GoRouter.of(context);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text('Pedido creado (#${order.docNum})')));
          router.go('/');
          router.push('/orders/${order.id}');
        } else if (state.status == SubmitStatus.failure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
                content: Text(state.error ?? 'No se pudo crear el pedido')));
        }
      },
      child: BlocBuilder<CartBloc, CartState>(
        builder: (context, cart) {
          return AppScaffold(
            title: 'Resumen del pedido',
            onBack: () => context.pop(),
            body: Column(
              children: [
                Expanded(child: _form(cart)),
                _footer(cart),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _form(CartState cart) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        if (cart.customer != null)
          SectionCard(
            child: Row(
              children: [
                InitialsAvatar(source: cart.customer!.name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cart.customer!.name,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text(cart.customer!.code,
                          style: GoogleFonts.inter(
                              color: AppColors.text2, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Datos',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SeriesSelect(
                value: _seriesId,
                onChanged: (v) => setState(() => _seriesId = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fecha de entrega (opcional)'),
                  child: Text(
                    _dueDate != null
                        ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                        : 'Sin fecha',
                    style: TextStyle(
                        color: _dueDate != null
                            ? AppColors.text1
                            : AppColors.text3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentsController,
                minLines: 1,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Comentarios (opcional)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Ítems (${cart.count})',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < cart.lines.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.lineSoft),
                _LineRow(
                  line: cart.lines[i],
                  onRemove: () => context
                      .read<CartBloc>()
                      .add(CartLineRemoved(cart.lines[i].itemCode)),
                ),
              ],
              const Divider(height: 1, color: AppColors.lineSoft),
              TextButton.icon(
                onPressed: () => context.pop(), // back to the catalog
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar más ítems'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(CartState cart) {
    return BlocBuilder<SubmitOrderBloc, SubmitOrderState>(
      builder: (context, submit) {
        final submitting = submit.status == SubmitStatus.submitting;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TOTAL',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text3,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              letterSpacing: 0.5)),
                      Text(formatMoney(cart.total),
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w800,
                              fontSize: 20)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GradientButton(
                      label: 'Confirmar pedido',
                      loading: submitting,
                      onPressed: cart.isEmpty ? null : () => _submit(cart),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeriesSelect extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _SeriesSelect({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SeriesBloc, SeriesState>(
      builder: (context, state) {
        if (state.status == SeriesStatus.loading) {
          return const InputDecorator(
            decoration: InputDecoration(labelText: 'Serie'),
            child: Text('Cargando…'),
          );
        }
        return DropdownButtonFormField<int?>(
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Serie (opcional)'),
          items: [
            const DropdownMenuItem<int?>(
                value: null, child: Text('Serie por defecto')),
            for (final s in state.series)
              DropdownMenuItem<int?>(
                  value: s.sapSeriesId, child: Text(s.sapSeriesName)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _LineRow extends StatelessWidget {
  final CartLine line;
  final VoidCallback onRemove;
  const _LineRow({required this.line, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final uom = line.salesUnitOfMeasure ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.itemName,
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text1,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text('${formatQty(line.quantity)} $uom · ${line.itemCode}',
                    style: GoogleFonts.inter(
                        color: AppColors.text2, fontSize: 12)),
              ],
            ),
          ),
          if (line.subtotal > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(formatMoney(line.subtotal),
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.text3),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
