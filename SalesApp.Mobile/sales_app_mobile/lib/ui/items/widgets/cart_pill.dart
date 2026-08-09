import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/format.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/pressable_scale.dart';

/// Floating cart pill (DESIGN.md): shell-gradient rounded rect fixed at the
/// bottom, showing the item count, running total and a "Ver pedido" affordance.
class CartPill extends StatelessWidget {
  final int count;
  final double total;
  final VoidCallback onTap;

  const CartPill({
    super.key,
    required this.count,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppGradients.shell,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                total > 0 ? formatMoney(total) : 'Ver pedido',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Row(
              children: [
                Text('Ver pedido',
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 13)),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
