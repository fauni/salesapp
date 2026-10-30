part of 'warehouses_bloc.dart';

enum WarehousesStatus { loading, success, failure }

enum WarehousesSaveStatus { idle, saving, success, failure }

class WarehousesState extends Equatable {
  final WarehousesStatus status;

  /// As last loaded/saved from the backend.
  final List<ManagedWarehouse> warehouses;

  /// Codes marked allowed in the screen (may differ from [warehouses] until saved).
  final Set<String> selected;
  final String query;
  final WarehousesSaveStatus saveStatus;
  final String? error;

  const WarehousesState({
    this.status = WarehousesStatus.loading,
    this.warehouses = const [],
    this.selected = const {},
    this.query = '',
    this.saveStatus = WarehousesSaveStatus.idle,
    this.error,
  });

  /// Warehouses matching [query] by code or name.
  List<ManagedWarehouse> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return warehouses;
    return warehouses
        .where((w) =>
            w.code.toLowerCase().contains(q) || w.name.toLowerCase().contains(q))
        .toList();
  }

  /// True when [selected] differs from what the backend has.
  bool get isDirty {
    final saved = {
      for (final w in warehouses)
        if (w.allowed) w.code,
    };
    return saved.length != selected.length || !saved.containsAll(selected);
  }

  WarehousesState copyWith({
    WarehousesStatus? status,
    List<ManagedWarehouse>? warehouses,
    Set<String>? selected,
    String? query,
    WarehousesSaveStatus? saveStatus,
    String? error,
  }) {
    return WarehousesState(
      status: status ?? this.status,
      warehouses: warehouses ?? this.warehouses,
      selected: selected ?? this.selected,
      query: query ?? this.query,
      saveStatus: saveStatus ?? this.saveStatus,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [status, warehouses, selected, query, saveStatus, error];
}
