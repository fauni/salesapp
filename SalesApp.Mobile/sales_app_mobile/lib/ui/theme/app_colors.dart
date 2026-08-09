import 'package:flutter/material.dart';

/// Color tokens — exact values from DESIGN.md. Never invent new colors; if a
/// value is missing here, ask before adding one.
class AppColors {
  AppColors._();

  static const sapBlue = Color(0xFF0064DC);
  static const sapBlueDeep = Color(0xFF004FB0);
  static const sapBlueTint = Color(0xFFEAF2FE);

  static const shell1 = Color(0xFF0A1E42); // darkest navy
  static const shell2 = Color(0xFF122B54); // lighter navy (gradients with shell1)

  static const positive = Color(0xFF127A45);
  static const positiveBg = Color(0xFFE7F5EC);
  static const critical = Color(0xFFA15B00); // "pending" status color (amber)
  static const criticalBg = Color(0xFFFCF1DF);
  static const negative = Color(0xFFB3261E);
  static const negativeBg = Color(0xFFFBEBEA);

  static const bgPage = Color(0xFFF3F5F9);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6E9EF);
  static const lineSoft = Color(0xFFEEF1F5);
  static const cardBorderGhost = Color(0x0B111A2E); // ~4.5% black hairline

  static const text1 = Color(0xFF111A2E); // primary text
  static const text2 = Color(0xFF5A6579); // secondary text
  static const text3 = Color(0xFF94A0B2); // tertiary / placeholder
}
