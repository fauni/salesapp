import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/sales_person.dart';
import '../../../data/network/api_error.dart';
import '../../../data/repositories/salesperson_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Opens a full-screen salesperson picker. Loads the active SAP salespersons on
/// demand, with a search box. Returns the chosen [SalesPerson], or null if
/// dismissed.
Future<SalesPerson?> showSalespersonPicker(
  BuildContext context, {
  required SalespersonRepository repository,
  int? selectedCode,
}) {
  return Navigator.of(context).push<SalesPerson>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SalespersonPickerScreen(
        repository: repository,
        selectedCode: selectedCode,
      ),
    ),
  );
}

class _SalespersonPickerScreen extends StatefulWidget {
  final SalespersonRepository repository;
  final int? selectedCode;
  const _SalespersonPickerScreen({
    required this.repository,
    this.selectedCode,
  });

  @override
  State<_SalespersonPickerScreen> createState() =>
      _SalespersonPickerScreenState();
}

class _SalespersonPickerScreenState extends State<_SalespersonPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  List<SalesPerson> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await widget.repository.listAll();
      if (!mounted) return;
      setState(() {
        _all = people;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  List<SalesPerson> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((p) =>
            p.name.toLowerCase().contains(q) || p.code.toString().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Empleado de ventas',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Buscar por nombre o código',
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
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: GoogleFonts.inter(
                    color: AppColors.negative, fontSize: 14)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final results = _filtered;
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Sin empleados que coincidan',
          style: GoogleFonts.inter(color: AppColors.text2, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = results[i];
        final selected = p.code == widget.selectedCode;
        return InkWell(
          onTap: () => Navigator.of(context).pop(p),
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.text1,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Código ${p.code}',
                        style: GoogleFonts.inter(
                            color: AppColors.text2, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
