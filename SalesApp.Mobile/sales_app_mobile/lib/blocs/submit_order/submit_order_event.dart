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
  final int? paymentTermsGroupCode;
  final List<CartLine> lines;

  // Best-effort GPS fix captured right before submit (see location_service.dart)
  // — null when denied/unavailable, sent to SAP's U_SL_Ubicacion when present.
  final double? latitude;
  final double? longitude;

  const OrderSubmitted({
    required this.customerCode,
    this.salesPersonCode,
    this.dueDate,
    this.comments,
    this.paymentTermsGroupCode,
    required this.lines,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [
        customerCode,
        salesPersonCode,
        dueDate,
        comments,
        paymentTermsGroupCode,
        lines,
        latitude,
        longitude,
      ];
}
