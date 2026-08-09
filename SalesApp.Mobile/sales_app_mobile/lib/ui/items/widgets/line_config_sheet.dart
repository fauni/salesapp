import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/format.dart';
import '../../../data/models/cart_line.dart';
import '../../../data/models/item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/gradient_button.dart';

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
  return showModalBottomSheet<LineSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LineConfigSheet(item: item, existing: existing),
  );
}

class _LineConfigSheet extends StatefulWidget {
  final Item item;
  final CartLine? existing;
  const _LineConfigSheet({required this.item, this.existing});

  @override
  State<_LineConfigSheet> createState() => _LineConfigSheetState();
}

class _LineConfigSheetState extends State<_LineConfigSheet> {
  late double _quantity;
  late final TextEditingController _priceController;
  late final TextEditingController _uomController;
  String? _warehouseCode;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _quantity = e?.quantity ?? 1;
    _priceController =
        TextEditingController(text: e?.unitPrice?.toString() ?? '');
    _uomController =
        TextEditingController(text: e?.salesUnitOfMeasure ?? '');
    _warehouseCode = e?.warehouseCode ??
        (widget.item.warehouses.isNotEmpty
            ? widget.item.warehouses.first.warehouseCode
            : null);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _uomController.dispose();
    super.dispose();
  }

  void _bump(double delta) {
    setState(() => _quantity = (_quantity + delta).clamp(1, 999999));
  }

  double? get _unitPrice => double.tryParse(_priceController.text.trim());
  double get _subtotal => _quantity * (_unitPrice ?? 0);

  void _save() {
    final uom = _uomController.text.trim();
    Navigator.of(context).pop(LineSaved(CartLine(
      itemCode: widget.item.code,
      itemName: widget.item.name,
      quantity: _quantity,
      salesUnitOfMeasure: uom.isEmpty ? null : uom,
      unitPrice: _unitPrice,
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
                        _warehouseDropdown(warehouses),
                        const SizedBox(height: 16),
                      ],
                      _label('Precio unitario (opcional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            hintText: 'Lo resuelve SAP si se deja vacío'),
                      ),
                      const SizedBox(height: 16),
                      _label('Unidad de venta (opcional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _uomController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                            hintText: 'UoM de venta (default del ítem)'),
                      ),
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
                width: 56,
                child: Text(
                  formatQty(_quantity),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text1,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
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

  Widget _warehouseDropdown(List<ItemWarehouseStock> warehouses) {
    return DropdownButtonFormField<String>(
      initialValue: _warehouseCode,
      items: [
        for (final w in warehouses)
          DropdownMenuItem(
            value: w.warehouseCode,
            child: Text(
                '${w.warehouseCode} · disp. ${formatQty(w.available)}'),
          ),
      ],
      onChanged: (v) => setState(() => _warehouseCode = v),
    );
  }
}
