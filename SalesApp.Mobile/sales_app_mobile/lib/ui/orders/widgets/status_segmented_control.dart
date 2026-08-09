import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/orders/orders_bloc.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Segmented control (DESIGN.md — NOT underline tabs) for the order status
/// filter. Active segment is SAP-blue filled; the track is a white pill.
class StatusSegmentedControl extends StatelessWidget {
  final OrderStatusFilter value;
  final ValueChanged<OrderStatusFilter> onChanged;

  const StatusSegmentedControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          for (final filter in OrderStatusFilter.values)
            Expanded(child: _segment(filter)),
        ],
      ),
    );
  }

  Widget _segment(OrderStatusFilter filter) {
    final selected = filter == value;
    return GestureDetector(
      onTap: selected ? null : () => onChanged(filter),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sapBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          filter.label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : AppColors.text2,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
