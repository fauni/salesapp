import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'brand_mark.dart';

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

class _Header extends StatelessWidget {
  final String username;
  final String subtitle;
  const _Header({required this.username, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          const BrandMark(size: 48),
          const SizedBox(width: 12),
          Expanded(
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
