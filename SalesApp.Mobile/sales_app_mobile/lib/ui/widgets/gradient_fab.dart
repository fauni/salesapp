import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'pressable_scale.dart';

/// Floating action button (DESIGN.md): bottom-right, SAP-blue gradient, strong
/// floating shadow. Used on the orders list to start a new order.
class GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const GradientFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          shape: BoxShape.circle,
          boxShadow: AppShadows.floating,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
