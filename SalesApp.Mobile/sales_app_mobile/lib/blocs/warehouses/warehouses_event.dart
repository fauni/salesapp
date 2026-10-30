part of 'warehouses_bloc.dart';

sealed class WarehousesEvent extends Equatable {
  const WarehousesEvent();
  @override
  List<Object?> get props => [];
}

class WarehousesStarted extends WarehousesEvent {
  const WarehousesStarted();
}

class WarehousesRefreshed extends WarehousesEvent {
  const WarehousesRefreshed();
}

class WarehousesSearchChanged extends WarehousesEvent {
  final String query;
  const WarehousesSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

/// Marks/unmarks one warehouse as allowed (local until saved).
class WarehouseToggled extends WarehousesEvent {
  final String code;
  const WarehouseToggled(this.code);
  @override
  List<Object?> get props => [code];
}

class WarehousesSaved extends WarehousesEvent {
  const WarehousesSaved();
}
