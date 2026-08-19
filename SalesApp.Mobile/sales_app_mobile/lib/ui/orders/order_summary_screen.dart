import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/submit_order/submit_order_bloc.dart';
import '../../core/format.dart';
import '../../core/location_service.dart';
import '../../data/models/branch.dart';
import '../../data/models/cart_line.dart';
import '../../data/models/order.dart';
import '../../data/models/payment_terms.dart';
import '../../data/models/project.dart';
import '../../data/models/sales_person.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/branch_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/payment_terms_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/salesperson_repository.dart';
import '../theme/app_colors.dart';
import 'widgets/branch_picker.dart';
import 'widgets/payment_terms_picker.dart';
import 'widgets/project_picker.dart';
import 'widgets/salesperson_picker.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/gradient_button.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';

/// New order — step 3: review and confirm. Builds the CreateOrderRequest from
/// the cart + the selected series / due date / comments, and POSTs it.
class OrderSummaryScreen extends StatefulWidget {
  /// When opened from "Duplicar pedido", the order being cloned — used to
  /// preload the header fields (salesperson, project, branch, comments) that
  /// live outside the CartBloc. Null for a normal new-order flow.
  final Order? sourceOrder;

  const OrderSummaryScreen({super.key, this.sourceOrder});

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  DateTime? _dueDate;
  bool _dueDateMissing = false;
  bool _paymentTermsMissing = false;
  final _commentsController = TextEditingController();

  // Loading state for the customer detail fetch (salesperson/payment-terms
  // defaults below) — the cart only holds the basic Customer.
  bool _loadingDetail = false;

  // Salesperson for the order. Defaults to the one assigned to the customer
  // (from the detail), but the rep can pick another.
  SalesPerson? _salesPerson;

  // Optional SAP project tagged on the order.
  Project? _project;

  // Optional SAP "Sucursal" (distribution rule) tagged on the order.
  Branch? _branch;

  // Codes read from widget.sourceOrder's lines while their display names are
  // being resolved from the catalogs (see _resolveSourceProjectName/Branch).
  String? _sourceProjectCode;
  String? _sourceBranchCode;

  // Payment terms for the order header. Defaults to the source order's own
  // (when duplicating) or the customer's assigned group (from the detail),
  // but the rep can override it — same pattern as _salesPerson.
  PaymentTerms? _paymentTerms;

  @override
  void initState() {
    super.initState();
    _preloadFromSourceOrder();
    _loadCustomerDetail();
  }

  /// When duplicating, preload the header fields the CartBloc doesn't carry:
  /// salesperson, project, branch, comments. These take priority over any
  /// later default (e.g. the customer's assigned salesperson) — they reflect
  /// what the original order was created with.
  void _preloadFromSourceOrder() {
    final source = widget.sourceOrder;
    if (source == null) return;

    if (source.salesPersonCode != null && source.salesPersonName != null) {
      _salesPerson = SalesPerson(
        code: source.salesPersonCode!,
        name: source.salesPersonName!,
      );
    }

    if (source.paymentTermsGroupCode != null &&
        source.paymentTermsGroupName != null) {
      _paymentTerms = PaymentTerms(
        code: source.paymentTermsGroupCode!,
        name: source.paymentTermsGroupName!,
      );
    }

    // Project/branch live per-line in SAP; every line was tagged the same way
    // from the order-wide pickers, so the first line that has one represents
    // the whole order. Only the code is on the line — resolve the display
    // name from the catalogs once loaded (see below).
    for (final line in source.lines) {
      _sourceProjectCode ??= line.projectCode;
      _sourceBranchCode ??= line.branchCode;
    }
    if (_sourceProjectCode != null) _resolveSourceProjectName();
    if (_sourceBranchCode != null) _resolveSourceBranchName();

    if ((source.comments ?? '').isNotEmpty) {
      _commentsController.text = source.comments!;
    }
  }

  Future<void> _resolveSourceProjectName() async {
    try {
      final all = await context.read<ProjectRepository>().listAll();
      final match =
          all.where((p) => p.code == _sourceProjectCode).firstOrNull;
      if (!mounted || match == null || _project != null) return;
      setState(() => _project = match);
    } on ApiException {
      // Non-critical: the rep can still pick a project manually.
    }
  }

  Future<void> _resolveSourceBranchName() async {
    try {
      final all = await context.read<BranchRepository>().listAll();
      final match = all.where((b) => b.code == _sourceBranchCode).firstOrNull;
      if (!mounted || match == null || _branch != null) return;
      setState(() => _branch = match);
    } on ApiException {
      // Non-critical: the rep can still pick a branch manually.
    }
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
        _loadingDetail = false;
        // Preselect the customer's assigned salesperson (unless the rep already
        // picked one, or the source order already set one). Needs both a code
        // and a resolved name to show.
        if (_salesPerson == null &&
            detail.salesPersonCode != null &&
            detail.salesPersonCode! > 0 &&
            detail.salesPersonName != null) {
          _salesPerson = SalesPerson(
            code: detail.salesPersonCode!,
            name: detail.salesPersonName!,
          );
        }
        // Same default-unless-already-set pattern for payment terms.
        if (_paymentTerms == null &&
            detail.paymentTermsGroupCode != null &&
            detail.paymentTermsGroupName != null) {
          _paymentTerms = PaymentTerms(
            code: detail.paymentTermsGroupCode!,
            name: detail.paymentTermsGroupName!,
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

  Future<void> _submit(CartState cart) async {
    // Due date and payment terms are required.
    if (_dueDate == null || _paymentTerms == null) {
      setState(() {
        _dueDateMissing = _dueDate == null;
        _paymentTermsMissing = _paymentTerms == null;
      });
      return;
    }
    final bloc = context.read<SubmitOrderBloc>();
    // Best-effort GPS fix for SAP's U_SL_Ubicacion — never blocks order
    // creation (see location_service.dart: null on denied/unavailable/timeout).
    // Captured here (not earlier) so it reflects where the rep is right when
    // confirming, and the GradientButton's own loading state already covers
    // this wait — no separate spinner needed.
    final location = await getCurrentLocationOrNull();
    bloc.add(OrderSubmitted(
      customerCode: cart.customer!.code,
      salesPersonCode: _salesPerson?.code,
      dueDate: _dueDate,
      comments: _commentsController.text.trim(),
      paymentTermsGroupCode: _paymentTerms?.code,
      lines: cart.lines,
      latitude: location?.$1,
      longitude: location?.$2,
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

  Future<void> _pickPaymentTerms() async {
    final picked = await showPaymentTermsPicker(
      context,
      repository: context.read<PaymentTermsRepository>(),
      selectedCode: _paymentTerms?.code,
    );
    if (picked != null) {
      setState(() {
        _paymentTerms = picked;
        _paymentTermsMissing = false;
      });
    }
  }

  Future<void> _pickProject() async {
    final picked = await showProjectPicker(
      context,
      repository: context.read<ProjectRepository>(),
      selectedCode: _project?.code,
    );
    if (picked != null) {
      setState(() => _project = picked);
      // Apply to every line already in the cart, and future ones too.
      context.read<CartBloc>().add(CartProjectSet(picked.code));
    }
  }

  Future<void> _pickBranch() async {
    final picked = await showBranchPicker(
      context,
      repository: context.read<BranchRepository>(),
      selectedCode: _branch?.code,
    );
    if (picked != null) {
      setState(() => _branch = picked);
      // Apply to every line already in the cart, and future ones too.
      context.read<CartBloc>().add(CartBranchSet(picked.code));
    }
  }

  /// "Agregar más ítems": in the normal new-order flow this summary sits
  /// pushed on top of the catalog (same shared CartBloc), so popping back
  /// works. When duplicating, the summary is opened directly (no catalog
  /// underneath) — push the duplicate flow's own catalog route instead, which
  /// shares this same CartBloc via its ShellRoute.
  void _goToCatalog() {
    final source = widget.sourceOrder;
    if (source != null) {
      context.push('/orders/${source.id}/duplicate/catalog');
    } else {
      context.pop();
    }
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
                onTap: _pickPaymentTerms,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Condición de pago',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    errorText: _paymentTermsMissing
                        ? 'Seleccioná una condición de pago'
                        : null,
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
                    _paymentTerms != null
                        ? _paymentTerms!.name
                        : 'Seleccionar condición de pago',
                    style: TextStyle(
                        color: _paymentTerms != null
                            ? AppColors.text1
                            : AppColors.text3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickProject,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Proyecto (opcional)',
                    prefixIcon: Icon(Icons.folder_outlined),
                    suffixIcon: Icon(Icons.chevron_right_rounded),
                  ),
                  child: Text(
                    _project != null
                        ? '${_project!.name} (${_project!.code})'
                        : 'Seleccionar proyecto',
                    style: TextStyle(
                        color: _project != null
                            ? AppColors.text1
                            : AppColors.text3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickBranch,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sucursal (opcional)',
                    prefixIcon: Icon(Icons.store_mall_directory_outlined),
                    suffixIcon: Icon(Icons.chevron_right_rounded),
                  ),
                  child: Text(
                    _branch != null
                        ? '${_branch!.name} (${_branch!.code})'
                        : 'Seleccionar sucursal',
                    style: TextStyle(
                        color: _branch != null
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
                onPressed: _goToCatalog,
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
