import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../data/models/item.dart';
import '../../data/network/api_error.dart';
import '../../data/repositories/item_repository.dart';

part 'items_event.dart';
part 'items_state.dart';

EventTransformer<E> _debounceRestart<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class ItemsBloc extends Bloc<ItemsEvent, ItemsState> {
  final ItemRepository _repository;

  ItemsBloc(this._repository) : super(const ItemsState()) {
    on<ItemsSearchChanged>(
      _onSearch,
      transformer: _debounceRestart(const Duration(milliseconds: 350)),
    );
    on<ItemsNextPageRequested>(_onNextPage);
  }

  Future<void> _onSearch(
    ItemsSearchChanged event,
    Emitter<ItemsState> emit,
  ) async {
    final query = event.query.trim();
    emit(state.copyWith(query: query, status: ItemsStatus.loading));
    try {
      final result = await _repository.search(query: query, page: 1);
      emit(state.copyWith(
        status: ItemsStatus.success,
        items: result.items,
        page: 1,
        totalCount: result.totalCount,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: ItemsStatus.failure,
        items: const [],
        error: e.message,
      ));
    }
  }

  Future<void> _onNextPage(
    ItemsNextPageRequested event,
    Emitter<ItemsState> emit,
  ) async {
    if (state.status != ItemsStatus.success ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    try {
      final next = state.page + 1;
      final result = await _repository.search(query: state.query, page: next);
      emit(state.copyWith(
        items: [...state.items, ...result.items],
        page: result.page,
        totalCount: result.totalCount,
        loadingMore: false,
      ));
    } on ApiException {
      // Keep what we have; just stop the "loading more" spinner.
      emit(state.copyWith(loadingMore: false));
    }
  }
}
