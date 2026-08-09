import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_drawer.dart';

/// Standard scaffold for screens.
///
/// - Top-level screens (default): shell-gradient top bar with a hamburger that
///   opens the side drawer.
/// - Sub-screens: pass [onBack] to show a back arrow in the same slot instead
///   (no drawer), per DESIGN.md's navigation model.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onBack;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isSubScreen = onBack != null;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      drawer: isSubScreen ? null : const AppDrawer(),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: isSubScreen
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        actions: actions,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.shell),
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
