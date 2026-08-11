import 'package:flutter/material.dart';

/// Color tokens — derived from the app [ColorScheme] (see [appColorScheme] in
/// app_theme.dart). Never invent new colors in screens; reference a token here.
class AppColors {
  AppColors._();

  // --- Brand / primary (was "sapBlue*") ---
  static const primary = Color(0xFF1E508D);       // primary actions, active tab
  static const primaryDeep = Color(0xFF0F315A);   // darker primary (onPrimaryContainer)
  static const primaryTint = Color(0xFFE8F1FA);   // subtle blue bg (search, banners)

  // Back-compat aliases so existing screens keep compiling.
  static const sapBlue = primary;
  static const sapBlueDeep = primaryDeep;
  static const sapBlueTint = primaryTint;

  // --- Shell (topbar, drawer, cart pill) — solid primary now ---
  static const shell1 = primary;
  static const shell2 = primary;

  // --- Semantic status colors ---
  static const positive = Color(0xFF00897B);      // secondary / teal (available, done)
  static const positiveBg = Color(0xFFE0F2F1);
  static const critical = Color(0xFFD97706);      // tertiary / amber (pending, partial)
  static const criticalBg = Color(0xFFFEF3C7);
  static const negative = Color(0xFFDC2626);      // error / red (rejected, high prio)
  static const negativeBg = Color(0xFFFEE2E2);

  // --- Surfaces ---
  static const bgPage = Color(0xFFF4F6F9);        // general grey background
  static const card = Color(0xFFFFFFFF);          // white cards
  static const line = Color(0xFFE5E7EB);          // dividers, card borders
  static const lineSoft = Color(0xFFF3F4F6);      // outlineVariant
  static const cardBorderGhost = Color(0x0B111A2E);

  // --- Text ---
  static const text1 = Color(0xFF1F2937);         // primary text / titles
  static const text2 = Color(0xFF6B7280);         // secondary text / inactive icons
  static const text3 = Color(0xFF94A0B2);         // tertiary / placeholder
}
