import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Corner radii (DESIGN.md).
class AppRadius {
  AppRadius._();

  static const double lg = 16;
  static const double md = 12; // cards, list/item/client rows
  static const double sm = 9;
  static const double sheet = 22; // bottom sheet top corners
  static const double button = 11;
  static const double pill = 999; // chips, badges, search pills (StadiumBorder)
}

/// Spacing (DESIGN.md — screen content padding etc.).
class AppSpacing {
  AppSpacing._();

  static const double screenH = 16; // 16–18 horizontal
  static const double screenTop = 16;
  static const double screenBottom = 30; // more if a sticky bar overlaps
}

/// Elevation via soft shadow, not hard borders (DESIGN.md).
class AppShadows {
  AppShadows._();

  /// Cards, list rows, item rows.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A111A2E), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D111A2E), blurRadius: 10, offset: Offset(0, 2)),
  ];

  /// Floating elements: cart pill, FAB, bottom sheet.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x47091635), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

/// Brand gradients (DESIGN.md).
class AppGradients {
  AppGradients._();

  /// Topbar, drawer, toast, cart pill, FAB context. ~160deg.
  static const shell = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.shell2, AppColors.shell1],
  );

  /// Primary actions (buttons, brand mark, blue avatars). 135deg.
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.sapBlue, AppColors.sapBlueDeep],
  );

  /// Client/order initials avatars (non-blue).
  static const avatar = shell;

  /// Login background — intentionally LIGHT (white -> bgPage), top to bottom.
  static const loginBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, AppColors.bgPage],
  );
}
