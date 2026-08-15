import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/users/users_bloc.dart';
import '../../data/models/app_user.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/status_message.dart';

/// Drawer section "Usuarios" (Administrator only): list SalesApp users, tap to
/// edit, "+" to create a new one.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Usuarios',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>('/users/new');
          if (created == true && context.mounted) {
            context.read<UsersBloc>().add(const UsersRefreshed());
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: BlocBuilder<UsersBloc, UsersState>(
        builder: (context, state) {
          switch (state.status) {
            case UsersStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case UsersStatus.failure:
              return StatusMessage(
                icon: Icons.error_outline_rounded,
                title: state.error ?? 'No se pudieron cargar los usuarios',
                actionLabel: 'Reintentar',
                onAction: () =>
                    context.read<UsersBloc>().add(const UsersRefreshed()),
              );
            case UsersStatus.success:
              if (state.users.isEmpty) {
                return const StatusMessage(
                  icon: Icons.people_outline_rounded,
                  title: 'Todavía no hay usuarios cargados',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<UsersBloc>();
                  bloc.add(const UsersRefreshed());
                  await bloc.stream
                      .firstWhere((s) => s.status != UsersStatus.loading);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: state.users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final user = state.users[i];
                    return _UserTile(
                      user: user,
                      onTap: () async {
                        final changed = await context.push<bool>(
                            '/users/${user.id}/edit',
                            extra: user);
                        if (changed == true && context.mounted) {
                          context.read<UsersBloc>().add(const UsersRefreshed());
                        }
                      },
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              InitialsAvatar(source: user.username, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      user.salesEmployeeCode != null
                          ? '${user.roleName} · Vendedor ${user.salesEmployeeCode}'
                          : user.roleName,
                      style: GoogleFonts.inter(
                          color: AppColors.text2, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _StatusChip(active: user.isActive),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.positive : AppColors.text3;
    final bg = active ? AppColors.positiveBg : AppColors.lineSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'ACTIVO' : 'INACTIVO',
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
