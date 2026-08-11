import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_assets.dart';
import '../../../core/format.dart';
import '../../../data/models/item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/pressable_scale.dart';

/// Item row for the catalog. Shows name, code and available stock. When the
/// item is already in the order, shows its quantity chip instead of an add icon.
class ItemTile extends StatelessWidget {
  final Item item;
  final double? inCartQuantity;
  final VoidCallback onTap;

  const ItemTile({
    super.key,
    required this.item,
    required this.onTap,
    this.inCartQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = inCartQuantity != null;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                AppAssets.productPlaceholder,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.code} · disp. ${formatQty(item.totalAvailable)}',
                    style: GoogleFonts.inter(
                        color: AppColors.text2, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (inCart)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.sapBlueTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '×${formatQty(inCartQuantity!)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.sapBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            else
              const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.sapBlue),
          ],
        ),
      ),
    );
  }
}
