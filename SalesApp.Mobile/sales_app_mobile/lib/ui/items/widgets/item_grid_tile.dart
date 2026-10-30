import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_assets.dart';
import '../../../core/format.dart';
import '../../../data/models/item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/pressable_scale.dart';

/// Grid variant of the catalog item card. Same data as [ItemTile] but laid out
/// vertically to fit a two-column grid. When the item is already in the order,
/// shows its quantity chip; otherwise an add icon in the top-right corner.
class ItemGridTile extends StatelessWidget {
  final Item item;
  final double? inCartQuantity;
  final VoidCallback onTap;

  const ItemGridTile({
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.asset(
                        AppAssets.productPlaceholder,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: inCart
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '×${formatQty(inCartQuantity!)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              color: AppColors.card,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_circle_rounded,
                                color: AppColors.primary, size: 24),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.text1,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
