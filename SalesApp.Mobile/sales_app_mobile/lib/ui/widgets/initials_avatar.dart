import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_tokens.dart';

/// Rounded-square avatar with initials over the shell gradient (DESIGN.md:
/// client/order avatars are rounded-squares, not circles).
class InitialsAvatar extends StatelessWidget {
  final String source;
  final double size;

  const InitialsAvatar({super.key, required this.source, this.size = 44});

  String get _initials {
    final parts =
        source.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppGradients.avatar,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        _initials,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
