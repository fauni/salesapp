import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_version_label.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';

/// Drawer section "Perfil": current user info + logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final username = auth.username ?? '-';

    return AppScaffold(
      title: 'Perfil',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SectionCard(
            child: Row(
              children: [
                InitialsAvatar(source: username, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text1,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                      if (auth.roles.isNotEmpty)
                        Text(auth.roles.join(', '),
                            style: GoogleFonts.inter(
                                color: AppColors.text2, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Cuenta',
            child: Column(
              children: [
                _row('Usuario', username),
                _row('Vendedor SAP', auth.salesEmployeeCode ?? '-'),
                _row('Roles', auth.roles.isEmpty ? '-' : auth.roles.join(', ')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.negative,
              side: const BorderSide(color: AppColors.negative),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: AppVersionLabel(color: AppColors.text3)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text1,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
