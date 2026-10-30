import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/format.dart';
import '../../../data/models/item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Opens a full-screen warehouse picker for an item. Shows each warehouse with
/// its stock breakdown (in stock / committed / ordered / available), a search
/// box, and an "only in-stock" filter. Returns the chosen warehouse code, or
/// null if dismissed. Display only: [inventoryUom] labels the stock figures
/// (SAP stock is in the inventory UoM) and [litersPerUnit] (items sold by
/// liters) adds each figure's liters next to it.
Future<String?> showWarehousePicker(
  BuildContext context, {
  required List<ItemWarehouseStock> warehouses,
  String? selectedCode,
  double? litersPerUnit,
  String? inventoryUom,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _WarehousePickerScreen(
        warehouses: warehouses,
        selectedCode: selectedCode,
        litersPerUnit: litersPerUnit,
        inventoryUom: inventoryUom,
      ),
    ),
  );
}

class _WarehousePickerScreen extends StatefulWidget {
  final List<ItemWarehouseStock> warehouses;
  final String? selectedCode;
  final double? litersPerUnit;
  final String? inventoryUom;
  const _WarehousePickerScreen({
    required this.warehouses,
    this.selectedCode,
    this.litersPerUnit,
    this.inventoryUom,
  });

  @override
  State<_WarehousePickerScreen> createState() => _WarehousePickerScreenState();
}

class _WarehousePickerScreenState extends State<_WarehousePickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlyInStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ItemWarehouseStock> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.warehouses.where((w) {
      if (_onlyInStock && w.available <= 0) return false;
      if (q.isEmpty) return true;
      return w.warehouseCode.toLowerCase().contains(q) ||
          (w.warehouseName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDeep,
        foregroundColor: Colors.white,
        title: Text(
          'Seleccionar almacén',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search + filter header on a white band, visually separate from
          // the scrolling list below.
          Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgPage,
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.text2),
                    hintText: 'Buscar almacén por nombre o código',
                    hintStyle: GoogleFonts.inter(
                        color: AppColors.text3, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StockFilterToggle(
                      active: _onlyInStock,
                      onToggle: () =>
                          setState(() => _onlyInStock = !_onlyInStock),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${results.length} almacén(es)',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 44, color: AppColors.text3),
                        const SizedBox(height: 10),
                        Text(
                          'Sin almacenes que coincidan',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (_onlyInStock) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Probá quitando el filtro "Solo con stock"',
                            style: GoogleFonts.inter(
                                color: AppColors.text2, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _WarehouseCard(
                      warehouse: results[i],
                      litersPerUnit: widget.litersPerUnit,
                      inventoryUom: widget.inventoryUom,
                      selected:
                          results[i].warehouseCode == widget.selectedCode,
                      onTap: () =>
                          Navigator.of(context).pop(results[i].warehouseCode),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Prominent on/off toggle for the "only in-stock" filter. Filled primary when
/// active, outlined and muted when off, so its state reads at a glance.
class _StockFilterToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onToggle;

  const _StockFilterToggle({required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.line,
              width: 1.5,
            ),
            boxShadow: active ? AppShadows.card : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.inventory_2_outlined,
                size: 18,
                color: active ? Colors.white : AppColors.text2,
              ),
              const SizedBox(width: 8),
              Text(
                'Solo con stock',
                style: GoogleFonts.plusJakartaSans(
                  color: active ? Colors.white : AppColors.text1,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  final ItemWarehouseStock warehouse;
  final bool selected;
  final VoidCallback onTap;

  /// Non-null for items sold by liters: stock figures also show liters.
  final double? litersPerUnit;

  /// Inventory UoM labelling the stock figures (e.g. "BIDON").
  final String? inventoryUom;

  const _WarehouseCard({
    required this.warehouse,
    required this.selected,
    required this.onTap,
    this.litersPerUnit,
    this.inventoryUom,
  });

  double? _liters(double units) {
    final perUnit = litersPerUnit;
    return perUnit == null || perUnit <= 0 ? null : units * perUnit;
  }

  @override
  Widget build(BuildContext context) {
    final w = warehouse;
    final hasStock = w.available > 0;
    final radius = BorderRadius.circular(AppRadius.md);

    // Material + InkWell so the ripple paints over the card background.
    return Material(
      color: selected ? AppColors.primaryTint : AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasStock ? AppColors.positiveBg : AppColors.lineSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.warehouse_outlined,
                      size: 21,
                      color: hasStock ? AppColors.positive : AppColors.text3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.displayName,
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
                            if (w.hasName)
                              _pill(
                                w.warehouseCode,
                                foreground: AppColors.text2,
                                background: AppColors.lineSoft,
                              ),
                            _pill(
                              hasStock
                                  ? 'Disponible: ${formatStock(w.available, uom: inventoryUom, liters: _liters(w.available))}'
                                  : 'Sin stock disponible',
                              icon: hasStock
                                  ? Icons.check_circle_rounded
                                  : Icons.remove_circle_outline_rounded,
                              foreground: hasStock
                                  ? AppColors.positive
                                  : AppColors.text2,
                              background: hasStock
                                  ? AppColors.positiveBg
                                  : AppColors.lineSoft,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? AppColors.primary : AppColors.line,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stock breakdown on a soft strip, separated by thin dividers.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.card : AppColors.bgPage,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _stockMetric('En stock', w.inStock),
                      const VerticalDivider(
                          width: 16, thickness: 1, color: AppColors.line),
                      _stockMetric('Comprom.', w.committed),
                      const VerticalDivider(
                          width: 16, thickness: 1, color: AppColors.line),
                      _stockMetric('Pedido', w.ordered),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small rounded label (code, stock state).
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

  Widget _stockMetric(String label, double value) {
    final liters = _liters(value);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: AppColors.text3, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            formatStock(value, uom: inventoryUom),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.text1,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (liters != null)
            Text(
              '${formatQty(liters)} L',
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
