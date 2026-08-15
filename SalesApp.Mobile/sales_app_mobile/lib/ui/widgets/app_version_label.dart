import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// "SalesApp v1.0.0 (1)" — reads the real version/build from the platform
/// (pubspec.yaml's `version:`) instead of hardcoding a string that would go
/// stale on the next bump. [color] lets callers match light/dark surfaces
/// (profile vs. drawer).
class AppVersionLabel extends StatelessWidget {
  final Color color;
  final double fontSize;

  const AppVersionLabel({super.key, required this.color, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final text = info == null
            ? 'Tomate Ventas'
            : 'Tomate Ventas v${info.version} (${info.buildNumber})';
        return Text(
          text,
          style: GoogleFonts.inter(color: color, fontSize: fontSize),
        );
      },
    );
  }
}
