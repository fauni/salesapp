import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_version_label.dart';

/// Side drawer (DESIGN.md navigation model — NOT bottom tabs). Shell gradient
/// background; the active section shows a left accent bar in SAP blue and a
/// tinted row background.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final location = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LogoBanner(),
              _Header(
                username: auth.username ?? '-',
                subtitle: auth.roles.isEmpty ? '' : auth.roles.join(', '),
              ),
              const SizedBox(height: 8),
              _DrawerItem(
                icon: Icons.receipt_long_rounded,
                label: 'Mis pedidos',
                selected: location == '/',
                onTap: () => _go(context, '/'),
              ),
              _DrawerItem(
                icon: Icons.add_shopping_cart_rounded,
                label: 'Nuevo pedido',
                selected: location == '/new-order',
                onTap: () => _go(context, '/new-order'),
              ),
              _DrawerItem(
                icon: Icons.people_alt_rounded,
                label: 'Clientes',
                selected: location == '/customers',
                onTap: () => _go(context, '/customers'),
              ),
              if (auth.roles.contains('Administrator'))
                _DrawerItem(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Usuarios',
                  selected: location == '/users',
                  onTap: () => _go(context, '/users'),
                ),
              if (auth.roles.contains('Administrator'))
                _DrawerItem(
                  icon: Icons.warehouse_rounded,
                  label: 'Almacenes',
                  selected: location == '/warehouses',
                  onTap: () => _go(context, '/warehouses'),
                ),
              _DrawerItem(
                icon: Icons.person_rounded,
                label: 'Perfil',
                selected: location == '/profile',
                onTap: () => _go(context, '/profile'),
              ),
              const Spacer(),
              const Divider(color: Colors.white24, height: 1),
              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                selected: false,
                onTap: () {
                  Navigator.of(context).pop(); // close the drawer
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
              ),
              const SizedBox(height: 12),
              const Center(
                child: AppVersionLabel(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String location) {
    Navigator.of(context).pop(); // close drawer first
    if (GoRouterState.of(context).matchedLocation != location) {
      context.go(location);
    }
  }
}

/// Brand banner at the top of the drawer — white strip so the logo (which has
/// its own light half) reads cleanly instead of fighting the dark shell
/// gradient behind the rest of the drawer.
class _LogoBanner extends StatelessWidget {
  const _LogoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Image.asset('assets/logos/tomate_facil_com.png', height: 36),
    );
  }
}

class _Header extends StatelessWidget {
  final String username;
  final String subtitle;
  const _Header({required this.username, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.08) : null,
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.sapBlue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
