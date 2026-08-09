import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/cart_line.dart';
import '../../data/models/customer.dart';

part 'cart_event.dart';
part 'cart_state.dart';

/// In-memory draft of the order being built (customer + lines). Lives for the
/// duration of the new-order flow; nothing is persisted (100% online).
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<CartCustomerSet>((event, emit) {
      emit(state.copyWith(customer: event.customer));
    });

    on<CartLineSaved>((event, emit) {
      final lines = [...state.lines];
      final index = lines.indexWhere((l) => l.itemCode == event.line.itemCode);
      if (index >= 0) {
        lines[index] = event.line;
      } else {
        lines.add(event.line);
      }
      emit(state.copyWith(lines: lines));
    });

    on<CartLineRemoved>((event, emit) {
      emit(state.copyWith(
        lines: state.lines.where((l) => l.itemCode != event.itemCode).toList(),
      ));
    });

    on<CartCleared>((event, emit) {
      emit(CartState(customer: state.customer));
    });
  }
}
