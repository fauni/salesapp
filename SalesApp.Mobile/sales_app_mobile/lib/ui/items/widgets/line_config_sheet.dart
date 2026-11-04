import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/cart/cart_bloc.dart';
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
///
/// Items sold by liters ([Item.sellsByLiters]) swap the quantity stepper for a
/// "Cantidad en litros" input: quantity becomes read-only (liters / liters per
/// unit, exact multiples only) and the UoM is fixed to the inventory UoM.
Future<LineSheetResult?> showLineConfigSheet(
  BuildContext context, {
  required Item item,
  CartLine? existing,
}) {
  final itemRepository = context.read<ItemRepository>();
  final customer = context.read<CartBloc>().state.customer;
  return showModalBottomSheet<LineSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LineConfigSheet(
      item: item,
      existing: existing,
      itemRepository: itemRepository,
      priceListNum: customer?.priceListNum,
      customerCurrency: customer?.currency,
    ),
  );
}

/// SAP's local currency — what SAP records documents in for customers set to
/// "##" (all currencies), which is most of the client's (verified on real
/// orders).
const _localCurrency = 'BS';

/// Currency of the price field — shown next to it AND saved on the cart line
/// (sent to SAP as the line `Currency`, so the price keeps the currency the rep
/// saw). The price list's currency when the price comes from a list, else the
/// customer's assigned currency, else [_localCurrency] for "##"/unset.
String _priceCurrency(ItemPrice? listPrice, String? customerCurrency) {
  final fromList = listPrice?.currency?.trim() ?? '';
  if (fromList.isNotEmpty) return fromList;
  final fromCustomer = customerCurrency?.trim() ?? '';
  if (fromCustomer.isNotEmpty && fromCustomer != '##') return fromCustomer;
  return _localCurrency;
}

class _LineConfigSheet extends StatefulWidget {
  final Item item;
  final CartLine? existing;
  final ItemRepository itemRepository;

  /// The cart customer's assigned SAP price list, used to prefill the price
  /// field for a new line. Null if no customer/price list is set.
  final int? priceListNum;

  /// The cart customer's SAP currency ("##" = all currencies). Fallback for
  /// the price label when the price doesn't come from a price list.
  final String? customerCurrency;

  const _LineConfigSheet({
    required this.item,
    required this.itemRepository,
    this.existing,
    this.priceListNum,
    this.customerCurrency,
  });

  @override
  State<_LineConfigSheet> createState() => _LineConfigSheetState();
}

class _LineConfigSheetState extends State<_LineConfigSheet> {
  late double _quantity;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  String? _priceError;

  /// Currency of the price (shown next to it and saved on the line).
  late final String _currency;

  // Sell-by-liters mode only (see showLineConfigSheet).
  late final TextEditingController _litersController;
  double? _liters;
  String? _litersError;
  String? _warehouseCode;

  // Numeric fields select their whole text on focus, so typing replaces the
  // value (a second tap places the cursor to edit a single digit).
  final _quantityFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _litersFocus = FocusNode();

  /// Price list the prefilled price came from (see initState). Null once the
  /// user edits the price by hand, since the hint would no longer be accurate.
  int? _priceListSource;

  /// Sell-by-liters only: the price field holds the price PER LITER, but the
  /// cart line / SAP keep the price per inventory unit (container). This is
  /// the prefilled per-unit price, used as-is until the user edits the field
  /// so the per-liter rounding shown never alters it.
  double? _prefilledUnitPrice;
  bool _priceEdited = false;

  // Sales UoM options, loaded on demand when the sheet opens.
  List<ItemUnitOfMeasure> _uoms = const [];
  String? _uomCode; // selected UoM code
  bool _uomLoading = true;
  String? _uomError;

  bool get _byLiters => widget.item.sellsByLiters;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _quantity = e?.quantity ?? (_byLiters ? 0 : 1);
    _quantityController =
        TextEditingController(text: _plainNumber(_quantity));
    // Lines saved before this field existed have no liters: derive them.
    _liters = _byLiters && e != null
        ? e.quantityInLiters ?? e.quantity * widget.item.litersPerUnit!
        : null;
    _litersController = TextEditingController(
        text: _liters == null ? '' : _plainNumber(_liters!));
    // Editing an existing line keeps its saved price untouched; a new line
    // prefills from the customer's assigned price list when there's a match.
    final matchedPrice = widget.item.priceFor(widget.priceListNum);
    // Per inventory unit (container) — that's how SAP's price list and the
    // cart line store it. Items sold by liters show it per liter instead.
    final resolvedPrice = e?.unitPrice ?? matchedPrice?.price;
    _prefilledUnitPrice = resolvedPrice;
    final shownPrice = resolvedPrice != null && _byLiters
        ? _round(resolvedPrice / widget.item.litersPerUnit!, 4)
        : resolvedPrice;
    _priceController = TextEditingController(
        text: shownPrice == null ? '' : _plainNumber(shownPrice));
    _priceListSource = e == null ? matchedPrice?.priceList : null;
    _currency =
        e?.currency ?? _priceCurrency(matchedPrice, widget.customerCurrency);
    _warehouseCode = e?.warehouseCode ??
        (widget.item.warehouses.isNotEmpty
            ? widget.item.warehouses.first.warehouseCode
            : null);
    if (_byLiters) {
      // Liters per unit is per INVENTORY unit, so the line must use it —
      // no UoM choice, nothing to load.
      _uomCode = widget.item.inventoryUom;
      _uomLoading = false;
    } else {
      _uomCode = e?.salesUnitOfMeasure; // may be null -> resolved after load
      _loadUoms();
    }
    _selectAllOnFocus(_quantityFocus, _quantityController);
    _selectAllOnFocus(_priceFocus, _priceController);
    _selectAllOnFocus(_litersFocus, _litersController);
  }

  void _selectAllOnFocus(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      if (!node.hasFocus) return;
      // Post-frame: the tap that focused the field positions the cursor
      // itself; selecting afterwards makes the select-all stick.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !node.hasFocus) return;
        controller.selection = TextSelection(
            baseOffset: 0, extentOffset: controller.text.length);
      });
    });
  }

  /// Number as typed-back text for editable fields: no grouping separators
  /// (formatQty's "1,000" would re-parse as 1.0, since "," is read as the
  /// decimal separator), no trailing ".0".
  static String _plainNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Rounds to [decimals] places, dropping binary float noise
  /// (12.35 * 20 = 247.00000000000003).
  static double _round(double v, int decimals) =>
      double.parse(v.toStringAsFixed(decimals));

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
    _litersController.dispose();
    _quantityFocus.dispose();
    _priceFocus.dispose();
    _litersFocus.dispose();
    super.dispose();
  }

  /// Liters typed: recompute the read-only quantity. A non-multiple leaves
  /// quantity at 0 and shows why, so it can't be saved.
  void _onLitersTyped(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    final units =
        parsed == null ? null : widget.item.quantityForLiters(parsed);
    setState(() {
      _liters = parsed;
      _quantity = units?.toDouble() ?? 0;
      _litersError = parsed == null || parsed <= 0 || units != null
          ? null
          : 'Debe ser múltiplo de '
              '${formatQty(widget.item.litersPerUnit!)} L';
    });
  }

  void _bump(double delta) {
    setState(() {
      _quantity = (_quantity + delta).clamp(1, 999999);
      _quantityController.text = _plainNumber(_quantity);
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
      _quantityController.text = _plainNumber(_quantity);
    });
  }

  /// What the price field holds: per unit, or per liter for items sold by
  /// liters. Accepts a comma as decimal separator ("12,5").
  double? get _typedPrice =>
      double.tryParse(_priceController.text.trim().replaceAll(',', '.'));

  /// Price per inventory unit (container) — what the cart line and SAP get.
  /// Sold by liters: price per liter × liters per unit.
  double? get _unitPrice {
    if (!_byLiters) return _typedPrice;
    if (!_priceEdited) return _prefilledUnitPrice;
    final perLiter = _typedPrice;
    return perLiter == null
        ? null
        : _round(perLiter * widget.item.litersPerUnit!, 6);
  }

  double get _subtotal => _quantity * (_unitPrice ?? 0);

  void _save() {
    if (_byLiters) {
      final liters = _liters;
      if (liters == null ||
          liters <= 0 ||
          widget.item.quantityForLiters(liters) == null) {
        setState(() => _litersError ??= 'Ingresá la cantidad en litros');
        return;
      }
    } else {
      _commitQuantity(); // guard against a blank/invalid quantity field
    }

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
      quantityInLiters: _byLiters ? _liters : null,
      unitPrice: price,
      currency: _currency,
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
                      _byLiters ? _litersBlock() : _quantityBlock(),
                      const SizedBox(height: 16),
                      if (warehouses.isNotEmpty) ...[
                        _label('Almacén'),
                        const SizedBox(height: 6),
                        _warehouseSelector(warehouses),
                        const SizedBox(height: 16),
                      ],
                      _label(_byLiters ? 'Precio por litro' : 'Precio unitario'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _priceController,
                        focusNode: _priceFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) => setState(() {
                          _priceError = null;
                          _priceListSource = null;
                          _priceEdited = true;
                        }),
                        decoration: InputDecoration(
                          prefixText: '${currencyLabel(_currency)} ',
                          prefixStyle: GoogleFonts.inter(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w600,
                          ),
                          suffixText: _byLiters ? '/ L' : null,
                          hintText: '0.00',
                          errorText: _priceError,
                        ),
                      ),
                      if (_byLiters && (_unitPrice ?? 0) > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Equivale a ${currencyLabel(_currency)} '
                          '${formatMoney(_unitPrice!)} por '
                          '${widget.item.inventoryUom ?? 'unidad'}',
                          style: GoogleFonts.inter(
                              color: AppColors.text2, fontSize: 12),
                        ),
                      ],
                      if (_priceListSource != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Precio según lista de precios N° $_priceListSource',
                          style: GoogleFonts.inter(
                              color: AppColors.text2, fontSize: 12),
                        ),
                      ],
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
                            '${currencyLabel(_currency)} '
                            '${formatMoney(_subtotal)}',
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
                  focusNode: _quantityFocus,
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

  /// Sell-by-liters input: the rep types liters, quantity is shown read-only.
  Widget _litersBlock() {
    final perUnit = widget.item.litersPerUnit!;
    final uom = widget.item.inventoryUom ?? 'und';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sapBlueTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cantidad en litros',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text1,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _litersController,
            focusNode: _litersFocus,
            autofocus: widget.existing == null,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: _onLitersTyped,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.text1,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'L',
              errorText: _litersError,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cantidad',
                  style: GoogleFonts.inter(
                      color: AppColors.text2, fontSize: 14)),
              Text(
                '${formatQty(_quantity)} $uom',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text1,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${formatQty(perUnit)} L por $uom',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
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
    if (_byLiters) {
      return Text(
        '${_uomCode ?? '—'} · unidad de inventario',
        style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
      );
    }
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

    final hasStock = (selected?.available ?? 0) > 0;
    final radius = BorderRadius.circular(AppRadius.md);

    // Material + InkWell so the ripple paints over the white card.
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected == null ? AppColors.line : AppColors.primary,
          width: selected == null ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _pickWarehouse(warehouses),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              // Leading tile: tinted when chosen, neutral while empty.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected == null
                      ? AppColors.lineSoft
                      : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.warehouse_outlined,
                  size: 22,
                  color: selected == null ? AppColors.text3 : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: selected == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar almacén',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${warehouses.length} almacén(es) disponibles',
                            style: GoogleFonts.inter(
                                color: AppColors.text3, fontSize: 12),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (selected.hasName)
                                _pill(
                                  selected.warehouseCode,
                                  foreground: AppColors.text2,
                                  background: AppColors.lineSoft,
                                ),
                              _pill(
                                hasStock
                                    ? 'Disponible: ${formatStock(selected.available, uom: widget.item.inventoryUom, liters: widget.item.litersFor(selected.available))}'
                                    : 'Sin stock disponible',
                                icon: hasStock
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                foreground: hasStock
                                    ? AppColors.positive
                                    : AppColors.negative,
                                background: hasStock
                                    ? AppColors.positiveBg
                                    : AppColors.negativeBg,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
            ],
          ),
        ),
      ),
    );
  }

  /// Small rounded label used under the warehouse name (code, stock state).
  Widget _pill(
    String text, {
    required Color foreground,
    required Color background,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWarehouse(List<ItemWarehouseStock> warehouses) async {
    final code = await showWarehousePicker(
      context,
      warehouses: warehouses,
      selectedCode: _warehouseCode,
      litersPerUnit: widget.item.litersPerUnit,
      inventoryUom: widget.item.inventoryUom,
    );
    if (code != null) {
      setState(() => _warehouseCode = code);
    }
  }
}
