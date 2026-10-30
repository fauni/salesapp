import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/managed_warehouse.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/warehouse_repository.dart';

part 'warehouses_event.dart';
part 'warehouses_state.dart';

/// Admin "Almacenes" screen: loads every SAP warehouse, lets the admin toggle
/// which ones are allowed and saves the whole list at once.
class WarehousesBloc extends Bloc<WarehousesEvent, WarehousesState> {
  final WarehouseRepository _repository;

  WarehousesBloc(this._repository) : super(const WarehousesState()) {
    on<WarehousesStarted>((event, emit) => _load(emit));
    on<WarehousesRefreshed>((event, emit) => _load(emit));
    on<WarehousesSearchChanged>(
        (event, emit) => emit(state.copyWith(query: event.query)));
    on<WarehouseToggled>(_onToggled);
    on<WarehousesSaved>(_onSaved);
  }

  Future<void> _load(Emitter<WarehousesState> emit) async {
    emit(state.copyWith(status: WarehousesStatus.loading));
    try {
      final warehouses = await _repository.list();
      emit(state.copyWith(
        status: WarehousesStatus.success,
        warehouses: warehouses,
        selected: _allowedCodes(warehouses),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: WarehousesStatus.failure, error: e.message));
    }
  }

  void _onToggled(WarehouseToggled event, Emitter<WarehousesState> emit) {
    final selected = {...state.selected};
    if (!selected.remove(event.code)) selected.add(event.code);
    emit(state.copyWith(
        selected: selected, saveStatus: WarehousesSaveStatus.idle));
  }

  Future<void> _onSaved(
    WarehousesSaved event,
    Emitter<WarehousesState> emit,
  ) async {
    emit(state.copyWith(saveStatus: WarehousesSaveStatus.saving));
    try {
      final warehouses = await _repository.saveAllowed(state.selected);
      emit(state.copyWith(
        warehouses: warehouses,
        selected: _allowedCodes(warehouses),
        saveStatus: WarehousesSaveStatus.success,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
          saveStatus: WarehousesSaveStatus.failure, error: e.message));
    }
  }

  static Set<String> _allowedCodes(List<ManagedWarehouse> warehouses) => {
        for (final w in warehouses)
          if (w.allowed) w.code,
      };
}
