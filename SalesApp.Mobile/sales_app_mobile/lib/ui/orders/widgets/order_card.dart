import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/format.dart';
import '../../../data/models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/pressable_scale.dart';
import 'order_status_badge.dart';

/// Order card (DESIGN.md): white surface, soft shadow, 3px SAP-blue left accent,
/// order number + client name top row with status badge top-right, divider,
/// then a 3-column meta row (Total / Fecha / Ítems) with uppercase micro-labels.
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const OrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: const Border(
            left: BorderSide(color: AppColors.sapBlue, width: 3),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.docNum}',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerName ?? order.customerCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppColors.text2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OrderStatusBadge(status: order.status),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _meta('TOTAL', formatMoney(order.docTotal)),
                  _meta('FECHA', formatDate(order.docDate)),
                  _meta('ÍTEMS', '${order.itemCount}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.text3,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.text1,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
