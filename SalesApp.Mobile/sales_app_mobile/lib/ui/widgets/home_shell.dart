import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Bottom navigation for the 3 top-level sections (Mis pedidos / Clientes /
/// Mi perfil). Wraps StatefulShellRoute's branch navigator — each branch
/// keeps its own navigation stack (so drilling into a customer detail and
/// switching tabs back doesn't lose that stack). Coexists with the side
/// drawer (DESIGN.md) — this bar is a shortcut to the 3 most-used sections,
/// the drawer still has the rest (Nuevo pedido, Usuarios, Cerrar sesión).
class HomeShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-active tab pops it back to its root, same as
          // most bottom-nav conventions (e.g. re-tapping "Clientes" while
          // deep in a customer detail returns to the list).
          initialLocation: index == navigationShell.currentIndex,
        ),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.primaryTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.text2,
          );
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            label: 'Mis pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt_rounded, color: AppColors.primary),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Mi perfil',
          ),
        ],
      ),
    );
  }
}
