import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Visual mapping for an order's status string (DESIGN.md status color mapping).
/// Pending is amber (a neutral waiting state), NOT red.
class OrderStatusStyle {
  final Color color;
  final Color background;
  final String label;

  const OrderStatusStyle(this.color, this.background, this.label);

  static OrderStatusStyle of(String status) {
    switch (status) {
      case 'approved':
        return const OrderStatusStyle(
            AppColors.positive, AppColors.positiveBg, 'Autorizado');
      case 'rejected':
        return const OrderStatusStyle(
            AppColors.negative, AppColors.negativeBg, 'Rechazado');
      case 'pending':
      default:
        return const OrderStatusStyle(
            AppColors.critical, AppColors.criticalBg, 'Pendiente');
    }
  }
}
