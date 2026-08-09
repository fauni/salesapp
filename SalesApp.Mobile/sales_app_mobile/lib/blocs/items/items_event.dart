part of 'items_bloc.dart';

sealed class ItemsEvent extends Equatable {
  const ItemsEvent();
  @override
  List<Object?> get props => [];
}

/// Fired on each keystroke; debounced. Resets to page 1.
class ItemsSearchChanged extends ItemsEvent {
  final String query;
  const ItemsSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

/// Infinite scroll — appends the next page.
class ItemsNextPageRequested extends ItemsEvent {
  const ItemsNextPageRequested();
}
