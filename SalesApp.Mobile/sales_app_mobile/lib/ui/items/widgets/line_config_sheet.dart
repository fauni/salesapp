import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format.dart';
import '../../../data/models/cart_line.dart';
import '../../../data/models/item.dart';
import '../../../data/models/item_unit_of_measure.dart';
import '../../../data/network/api_error.dart';
import '../../../data/repositories/item_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/gradient_button.dart';
import 'warehouse_picker.dart';

/// Result of the line-config bottom sheet.
sealed class LineSheetResult {}

class LineSaved extends LineSheetResult {
  final CartLine line;
  LineSaved(this.line);
}

class LineRemoved extends LineSheetResult {}

/// Opens the line-item config sheet (DESIGN.md screen 6). Sales UoM only (no
/// TFE UoM). Fields limited to what the backend order line supports:
/// quantity, warehouse, optional unit price, optional sales UoM.
Future<LineSheetResult?> showLineConfigSheet(
  BuildContext context, {
  required Item item,
  CartLine? existing,
}) {
  final itemRepository = context.read<ItemRepository>();
  return showModalBottomSheet<LineSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LineConfigSheet(
      item: item,
      existing: existing,
      itemRepository: itemRepository,
    ),
  );
}

class _LineConfigSheet extends StatefulWidget {
  final Item item;
  final CartLine? existing;
  final ItemRepository itemRepository;
  const _LineConfigSheet({
    required this.item,
    required this.itemRepository,
    this.existing,
  });

  @override
  State<_LineConfigSheet> createState() => _LineConfigSheetState();
}

class _LineConfigSheetState extends State<_LineConfigSheet> {
  late double _quantity;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  String? _priceError;
  String? _warehouseCode;

  // Sales UoM options, loaded on demand when the sheet opens.
  List<ItemUnitOfMeasure> _uoms = const [];
  String? _uomCode; // selected UoM code
  bool _uomLoading = true;
  String? _uomError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _quantity = e?.quantity ?? 1;
    _quantityController =
        TextEditingController(text: formatQty(_quantity));
    _priceController =
        TextEditingController(text: e?.unitPrice?.toString() ?? '');
    _uomCode = e?.salesUnitOfMeasure; // may be null -> resolved after load
    _warehouseCode = e?.warehouseCode ??
        (widget.item.warehouses.isNotEmpty
            ? widget.item.warehouses.first.warehouseCode
            : null);
    _loadUoms();
  }

  Future<void> _loadUoms() async {
    setState(() {
      _uomLoading = true;
      _uomError = null;
    });
    try {
      final uoms =
          await widget.itemRepository.unitsOfMeasure(widget.item.code);
      if (!mounted) return;
      setState(() {
        _uoms = uoms;
        _uomLoading = false;
        // Keep the existing line's UoM if it's still valid; otherwise pick the
        // item's default (or the first option).
        final codes = uoms.map((u) => u.code).toSet();
        if (_uomCode == null || !codes.contains(_uomCode)) {
          _uomCode = uoms.isEmpty
              ? null
              : (uoms.firstWhere((u) => u.isDefault, orElse: () => uoms.first))
                  .code;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uomLoading = false;
        _uomError = e.message;
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _bump(double delta) {
    setState(() {
      _quantity = (_quantity + delta).clamp(1, 999999);
      _quantityController.text = formatQty(_quantity);
    });
  }

  /// User typed in the quantity field. Parse permissively; an empty/invalid
  /// entry leaves [_quantity] untouched (it's re-clamped on submit/blur).
  void _onQuantityTyped(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed != null) {
      setState(() => _quantity = parsed);
    } else {
      setState(() {});
    }
  }

  /// Normalize the field when editing finishes: clamp to >= 1 and rewrite the
  /// text so a blank/zero entry can't be saved.
  void _commitQuantity() {
    final clamped = _quantity < 1 ? 1.0 : _quantity.clamp(1, 999999);
    setState(() {
      _quantity = clamped.toDouble();
      _quantityController.text = formatQty(_quantity);
    });
  }

  double? get _unitPrice => double.tryParse(_priceController.text.trim());
  double get _subtotal => _quantity * (_unitPrice ?? 0);

  void _save() {
    _commitQuantity(); // guard against a blank/invalid quantity field

    // Unit price is now required and must be > 0.
    final price = _unitPrice;
    if (price == null || price <= 0) {
      setState(() => _priceError = 'Ingresá un precio unitario válido');
      return;
    }

    Navigator.of(context).pop(LineSaved(CartLine(
      itemCode: widget.item.code,
      itemName: widget.item.name,
      quantity: _quantity,
      salesUnitOfMeasure: _uomCode,
      unitPrice: price,
      warehouseCode: _warehouseCode,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final warehouses = widget.item.warehouses;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgPage,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.name,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.text1,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _quantityBlock(),
                      const SizedBox(height: 16),
                      if (warehouses.isNotEmpty) ...[
                        _label('Almacén'),
                        const SizedBox(height: 6),
                        _warehouseSelector(warehouses),
                        const SizedBox(height: 16),
                      ],
                      _label('Precio unitario'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) => setState(() => _priceError = null),
                        decoration: InputDecoration(
                          prefixText: 'Bs. ',
                          prefixStyle: GoogleFonts.inter(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: '0.00',
                          errorText: _priceError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Unidad de venta'),
                      const SizedBox(height: 6),
                      _uomField(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal',
                              style: GoogleFonts.inter(
                                  color: AppColors.text2, fontSize: 14)),
                          Text(
                            formatMoney(_subtotal),
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    if (editing) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(LineRemoved()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.negative,
                            side: const BorderSide(color: AppColors.negative),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Quitar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: GradientButton(
                        label: editing ? 'Guardar' : 'Agregar',
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
      );

  Widget _quantityBlock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sapBlueTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Cantidad',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text1,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          Row(
            children: [
              _stepButton(Icons.remove_rounded, () => _bump(-1)),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _quantityController,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: _onQuantityTyped,
                  onEditingComplete: _commitQuantity,
                  onTapOutside: (_) {
                    _commitQuantity();
                    FocusScope.of(context).unfocus();
                  },
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text1,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              _stepButton(Icons.add_rounded, () => _bump(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.sapBlue, size: 20),
      ),
    );
  }

  Widget _uomField() {
    if (_uomLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Cargando unidades…',
                style: TextStyle(color: AppColors.text2, fontSize: 13)),
          ],
        ),
      );
    }
    if (_uomError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(_uomError!,
                style: const TextStyle(
                    color: AppColors.negative, fontSize: 13)),
          ),
          TextButton(onPressed: _loadUoms, child: const Text('Reintentar')),
        ],
      );
    }
    if (_uoms.isEmpty) {
      return const Text('Sin unidades disponibles',
          style: TextStyle(color: AppColors.text2, fontSize: 13));
    }
    return DropdownButtonFormField<String>(
      initialValue: _uomCode,
      items: [
        for (final u in _uoms)
          DropdownMenuItem(
            value: u.code,
            child: Text(u.code == u.name ? u.code : '${u.code} · ${u.name}'),
          ),
      ],
      onChanged: (v) => setState(() => _uomCode = v),
    );
  }

  Widget _warehouseSelector(List<ItemWarehouseStock> warehouses) {
    final selected = _warehouseCode == null
        ? null
        : warehouses.cast<ItemWarehouseStock?>().firstWhere(
              (w) => w?.warehouseCode == _warehouseCode,
              orElse: () => null,
            );

    return InkWell(
      onTap: () => _pickWarehouse(warehouses),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: selected == null
                  ? Text('Seleccionar almacén',
                      style: GoogleFonts.inter(
                          color: AppColors.text3, fontSize: 14))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.warehouseCode,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Disponible: ${formatQty(selected.available)}',
                          style: GoogleFonts.inter(
                              color: AppColors.text2, fontSize: 12),
                        ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.text2),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWarehouse(List<ItemWarehouseStock> warehouses) async {
    final code = await showWarehousePicker(
      context,
      warehouses: warehouses,
      selectedCode: _warehouseCode,
    );
    if (code != null) {
      setState(() => _warehouseCode = code);
    }
  }
}
