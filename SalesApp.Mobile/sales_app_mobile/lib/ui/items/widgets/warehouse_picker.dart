import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/format.dart';
import '../../../data/models/item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Opens a full-screen warehouse picker for an item. Shows each warehouse with
/// its stock breakdown (in stock / committed / ordered / available), a search
/// box, and an "only in-stock" filter. Returns the chosen warehouse code, or
/// null if dismissed.
Future<String?> showWarehousePicker(
  BuildContext context, {
  required List<ItemWarehouseStock> warehouses,
  String? selectedCode,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _WarehousePickerScreen(
        warehouses: warehouses,
        selectedCode: selectedCode,
      ),
    ),
  );
}

class _WarehousePickerScreen extends StatefulWidget {
  final List<ItemWarehouseStock> warehouses;
  final String? selectedCode;
  const _WarehousePickerScreen({
    required this.warehouses,
    this.selectedCode,
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
      return w.warehouseCode.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
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
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.shell),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Buscar almacén por código',
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StockFilterToggle(
                  active: _onlyInStock,
                  onToggle: () =>
                      setState(() => _onlyInStock = !_onlyInStock),
                ),
                const Spacer(),
                Text(
                  '${results.length} almacén(es)',
                  style: GoogleFonts.inter(
                      color: AppColors.text2, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'Sin almacenes que coincidan',
                      style: GoogleFonts.inter(
                          color: AppColors.text2, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _WarehouseCard(
                      warehouse: results[i],
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

  const _WarehouseCard({
    required this.warehouse,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = warehouse;
    final hasStock = w.available > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    w.warehouseCode,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasStock
                  ? 'Disponible: ${formatQty(w.available)}'
                  : 'Sin stock disponible',
              style: GoogleFonts.inter(
                color: hasStock ? AppColors.positive : AppColors.text2,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stockMetric('En stock', w.inStock),
                _stockMetric('Comprom.', w.committed),
                _stockMetric('Pedido', w.ordered),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockMetric(String label, num value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: AppColors.text3, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            formatQty(value),
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
