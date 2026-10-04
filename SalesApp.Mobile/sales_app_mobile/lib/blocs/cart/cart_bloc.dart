import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/cart_line.dart';
import '../../data/models/customer.dart';
import '../../data/models/order.dart';

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
      // New/edited lines inherit the order-wide project/branch automatically.
      final line = event.line.copyWith(
        projectCode: state.projectCode,
        branchCode: state.branchCode,
      );
      final lines = [...state.lines];
      final index = lines.indexWhere((l) => l.itemCode == line.itemCode);
      if (index >= 0) {
        lines[index] = line;
      } else {
        lines.add(line);
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

    on<CartProjectSet>((event, emit) {
      final lines = [
        for (final l in state.lines)
          l.copyWith(projectCode: event.projectCode, keepBranchCode: true),
      ];
      emit(state.copyWith(
        lines: lines,
        projectCode: event.projectCode,
        clearProjectCode: event.projectCode == null,
      ));
    });

    on<CartBranchSet>((event, emit) {
      final lines = [
        for (final l in state.lines)
          l.copyWith(branchCode: event.branchCode, keepProjectCode: true),
      ];
      emit(state.copyWith(
        lines: lines,
        branchCode: event.branchCode,
        clearBranchCode: event.branchCode == null,
      ));
    });

    on<CartInitializedFromOrder>((event, emit) {
      final order = event.order;
      final customer = Customer(
        code: order.customerCode,
        name: order.customerName ?? order.customerCode,
      );
      final lines = [
        for (final l in order.lines)
          CartLine(
            itemCode: l.itemCode,
            itemName: l.description ?? l.itemCode,
            quantity: l.quantity,
            salesUnitOfMeasure: l.salesUnitOfMeasure,
            quantityInLiters: l.quantityInLiters,
            unitPrice: l.unitPrice,
            warehouseCode: l.warehouseCode,
            projectCode: l.projectCode,
            branchCode: l.branchCode,
          ),
      ];
      emit(CartState(customer: customer, lines: lines));
    });
  }
}
