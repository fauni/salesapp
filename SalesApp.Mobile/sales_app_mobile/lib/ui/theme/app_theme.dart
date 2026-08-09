import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Builds the app-wide [ThemeData] from the DESIGN.md tokens.
///
/// Typography: Plus Jakarta Sans for UI chrome (headings, titles, labels,
/// buttons), Inter for body/input text.
///
/// NOTE (on-prem): `google_fonts` fetches fonts over the network on first run
/// and caches them. The client's server may have no internet — before
/// production, bundle the .ttf files as assets so fonts render offline.
ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);

  final jakarta = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
  final textTheme = jakarta.copyWith(
    // Body / input text uses Inter.
    bodyLarge: GoogleFonts.inter(textStyle: jakarta.bodyLarge),
    bodyMedium: GoogleFonts.inter(textStyle: jakarta.bodyMedium),
    bodySmall: GoogleFonts.inter(textStyle: jakarta.bodySmall),
  ).apply(
    bodyColor: AppColors.text1,
    displayColor: AppColors.text1,
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.sapBlue,
    primary: AppColors.sapBlue,
    surface: AppColors.card,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.bgPage,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, // real bg comes from a gradient
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.sapBlue, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.text3),
      labelStyle: const TextStyle(color: AppColors.text2),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
  );
}
