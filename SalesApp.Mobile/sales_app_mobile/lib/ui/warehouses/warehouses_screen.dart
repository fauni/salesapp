import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../data/models/managed_warehouse.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/elevated_search_bar.dart';
import '../widgets/gradient_button.dart';
import '../widgets/status_message.dart';

/// Drawer section "Almacenes" (Administrator only): marks which SAP warehouses
/// sales orders may use. The list is global (same for every user); a warehouse
/// left unmarked never shows up in the order's warehouse picker, and with none
/// marked no warehouse is offered at all.
class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WarehousesBloc, WarehousesState>(
      listenWhen: (a, b) => a.saveStatus != b.saveStatus,
      listener: (context, state) {
        switch (state.saveStatus) {
          case WarehousesSaveStatus.success:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                  const SnackBar(content: Text('Almacenes guardados')));
          case WarehousesSaveStatus.failure:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                  content: Text(
                      state.error ?? 'No se pudieron guardar los almacenes')));
          case WarehousesSaveStatus.idle:
          case WarehousesSaveStatus.saving:
            break;
        }
      },
      child: AppScaffold(
        title: 'Almacenes',
        body: BlocBuilder<WarehousesBloc, WarehousesState>(
          builder: (context, state) {
            switch (state.status) {
              case WarehousesStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case WarehousesStatus.failure:
                return StatusMessage(
                  icon: Icons.error_outline_rounded,
                  title: state.error ?? 'No se pudieron cargar los almacenes',
                  actionLabel: 'Reintentar',
                  onAction: () => context
                      .read<WarehousesBloc>()
                      .add(const WarehousesRefreshed()),
                );
              case WarehousesStatus.success:
                return _content(state);
            }
          },
        ),
      ),
    );
  }

  Widget _content(WarehousesState state) {
    final visible = state.visible;
    return Column(
      children: [
        Container(
          color: AppColors.bgPage,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedSearchBar(
                controller: _searchController,
                hintText: 'Buscar almacén por código o nombre',
                onChanged: (q) => context
                    .read<WarehousesBloc>()
                    .add(WarehousesSearchChanged(q)),
              ),
              const SizedBox(height: 12),
              Text(
                '${state.selected.length} de ${state.warehouses.length} permitidos',
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
              ),
              if (state.selected.isEmpty) ...[
                const SizedBox(height: 8),
                const _NoneAllowedWarning(),
              ],
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? StatusMessage(
                  icon: Icons.warehouse_outlined,
                  title: state.query.isNotEmpty
                      ? 'Sin resultados para "${state.query}"'
                      : 'No hay almacenes en SAP',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final w = visible[i];
                    return _WarehouseTile(
                      warehouse: w,
                      allowed: state.selected.contains(w.code),
                      onToggle: () => context
                          .read<WarehousesBloc>()
                          .add(WarehouseToggled(w.code)),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: GradientButton(
              label: 'Guardar cambios',
              loading: state.saveStatus == WarehousesSaveStatus.saving,
              onPressed: state.isDirty
                  ? () => context
                      .read<WarehousesBloc>()
                      .add(const WarehousesSaved())
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _WarehouseTile extends StatelessWidget {
  final ManagedWarehouse warehouse;
  final bool allowed;
  final VoidCallback onToggle;

  const _WarehouseTile({
    required this.warehouse,
    required this.allowed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.warehouse_rounded,
                  color: allowed ? AppColors.primary : AppColors.text3),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(warehouse.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(warehouse.code,
                        style: GoogleFonts.inter(
                            color: AppColors.text2, fontSize: 13)),
                  ],
                ),
              ),
              Switch(value: allowed, onChanged: (_) => onToggle()),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoneAllowedWarning extends StatelessWidget {
  const _NoneAllowedWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ningún almacén permitido: los vendedores no podrán elegir '
              'almacén en los pedidos.',
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
