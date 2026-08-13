import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/submit_order/submit_order_bloc.dart';
import '../../core/format.dart';
import '../../data/models/cart_line.dart';
import '../../data/models/customer.dart';
import '../../data/models/sales_person.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/salesperson_repository.dart';
import '../theme/app_colors.dart';
import 'widgets/salesperson_picker.dart';
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
  DateTime? _dueDate;
  bool _dueDateMissing = false;
  final _commentsController = TextEditingController();

  // Full customer detail (payment terms etc.), loaded on demand — the cart only
  // holds the basic Customer.
  CustomerDetail? _customerDetail;
  bool _loadingDetail = false;

  // Salesperson for the order. Defaults to the one assigned to the customer
  // (from the detail), but the rep can pick another.
  SalesPerson? _salesPerson;

  @override
  void initState() {
    super.initState();
    _loadCustomerDetail();
  }

  Future<void> _loadCustomerDetail() async {
    final code = context.read<CartBloc>().state.customer?.code;
    if (code == null) return;
    setState(() => _loadingDetail = true);
    try {
      final detail =
          await context.read<CustomerRepository>().getByCode(code);
      if (!mounted) return;
      setState(() {
        _customerDetail = detail;
        _loadingDetail = false;
        // Preselect the customer's assigned salesperson (unless the rep already
        // picked one). Needs both a code and a resolved name to show.
        if (_salesPerson == null &&
            detail.salesPersonCode != null &&
            detail.salesPersonCode! > 0 &&
            detail.salesPersonName != null) {
          _salesPerson = SalesPerson(
            code: detail.salesPersonCode!,
            name: detail.salesPersonName!,
          );
        }
      });
    } on ApiException {
      // Non-critical: the summary still works without the payment terms.
      if (!mounted) return;
      setState(() => _loadingDetail = false);
    }
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  void _submit(CartState cart) {
    // Due date is required.
    if (_dueDate == null) {
      setState(() => _dueDateMissing = true);
      return;
    }
    context.read<SubmitOrderBloc>().add(OrderSubmitted(
          customerCode: cart.customer!.code,
          salesPersonCode: _salesPerson?.code,
          dueDate: _dueDate,
          comments: _commentsController.text.trim(),
          lines: cart.lines,
        ));
  }

  Future<void> _pickSalesperson() async {
    final picked = await showSalespersonPicker(
      context,
      repository: context.read<SalespersonRepository>(),
      selectedCode: _salesPerson?.code,
    );
    if (picked != null) setState(() => _salesPerson = picked);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueDateMissing = false;
      });
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                _customerCommercialInfo(),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Datos',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _pickSalesperson,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Empleado de ventas',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: _loadingDetail
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                  ),
                  child: Text(
                    _salesPerson != null
                        ? '${_salesPerson!.name} (${_salesPerson!.code})'
                        : 'Seleccionar empleado',
                    style: TextStyle(
                        color: _salesPerson != null
                            ? AppColors.text1
                            : AppColors.text3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de entrega',
                    prefixIcon: const Icon(Icons.event_rounded),
                    suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                    errorText:
                        _dueDateMissing ? 'Seleccioná una fecha de entrega' : null,
                  ),
                  child: Text(
                    _dueDate != null
                        ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                        : 'Seleccionar fecha',
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
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comentarios (opcional)',
                  hintText: 'Notas para este pedido…',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
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

  /// Commercial detail resolved from the customer detail (price list + payment
  /// terms). Shows a spinner while loading and muted placeholders when SAP has
  /// no value.
  Widget _customerCommercialInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: AppColors.lineSoft),
          const SizedBox(height: 12),
          _infoRow(
            icon: Icons.sell_outlined,
            label: 'Lista de precios',
            value: _customerDetail?.priceListName,
            emptyText: 'No asignada',
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.payments_outlined,
            label: 'Condición de pago',
            value: _customerDetail?.paymentTermsGroupName,
            emptyText: 'No especificada',
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String? value,
    required String emptyText,
  }) {
    Widget trailing;
    if (_loadingDetail) {
      trailing = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      final empty = value == null || value.isEmpty;
      trailing = Text(
        empty ? emptyText : value,
        style: GoogleFonts.plusJakartaSans(
          color: empty ? AppColors.text3 : AppColors.text1,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      );
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.text2),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
        const Spacer(),
        Flexible(child: Align(alignment: Alignment.centerRight, child: trailing)),
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
