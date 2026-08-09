import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../order_status_style.dart';

/// Pill badge (DESIGN.md): uppercase, 10px, bold, tinted background matching
/// the status color.
class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = OrderStatusStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: style.color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
