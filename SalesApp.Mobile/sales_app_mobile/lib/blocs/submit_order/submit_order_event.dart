part of 'submit_order_bloc.dart';

sealed class SubmitOrderEvent extends Equatable {
  const SubmitOrderEvent();
  @override
  List<Object?> get props => [];
}

class OrderSubmitted extends SubmitOrderEvent {
  final String customerCode;
  final int? salesPersonCode;
  final DateTime? dueDate;
  final String? comments;
  final List<CartLine> lines;

  const OrderSubmitted({
    required this.customerCode,
    this.salesPersonCode,
    this.dueDate,
    this.comments,
    required this.lines,
  });

  @override
  List<Object?> get props =>
      [customerCode, salesPersonCode, dueDate, comments, lines];
}
