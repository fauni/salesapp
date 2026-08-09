import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Rounded-square brand mark with the primary (SAP blue) gradient.
/// Used on the login screen and the drawer header.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Icon(Icons.receipt_long_rounded,
          color: Colors.white, size: size * 0.5),
    );
  }
}
