import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/sap_accounts/sap_accounts_bloc.dart';
import '../../data/models/sap_account.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/status_message.dart';

/// Drawer section "Usuarios SAP" (Administrator only): the SAP users the
/// backend connects to the Service Layer with. Tap to edit, "+" to add one.
class SapAccountsScreen extends StatelessWidget {
  const SapAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Usuarios SAP',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>('/sap-accounts/new');
          if (created == true && context.mounted) {
            context.read<SapAccountsBloc>().add(const SapAccountsRefreshed());
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: BlocBuilder<SapAccountsBloc, SapAccountsState>(
        builder: (context, state) {
          switch (state.status) {
            case SapAccountsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case SapAccountsStatus.failure:
              return StatusMessage(
                icon: Icons.error_outline_rounded,
                title: state.error ?? 'No se pudieron cargar los usuarios SAP',
                actionLabel: 'Reintentar',
                onAction: () => context
                    .read<SapAccountsBloc>()
                    .add(const SapAccountsRefreshed()),
              );
            case SapAccountsStatus.success:
              if (state.accounts.isEmpty) {
                return const StatusMessage(
                  icon: Icons.key_outlined,
                  title: 'Todavía no hay usuarios SAP cargados. Mientras '
                      'tanto, todos usan la cuenta técnica del servidor.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<SapAccountsBloc>();
                  bloc.add(const SapAccountsRefreshed());
                  await bloc.stream
                      .firstWhere((s) => s.status != SapAccountsStatus.loading);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: state.accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final account = state.accounts[i];
                    return _SapAccountTile(
                      account: account,
                      onTap: () async {
                        final changed = await context.push<bool>(
                            '/sap-accounts/${account.id}/edit',
                            extra: account);
                        if (changed == true && context.mounted) {
                          context
                              .read<SapAccountsBloc>()
                              .add(const SapAccountsRefreshed());
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

class _SapAccountTile extends StatelessWidget {
  final SapAccount account;
  final VoidCallback onTap;
  const _SapAccountTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final users = account.userCount == 1
        ? '1 usuario'
        : '${account.userCount} usuarios';
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
              InitialsAvatar(source: account.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      'SAP: ${account.username} · $users',
                      style: GoogleFonts.inter(
                          color: AppColors.text2, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _StatusChip(active: account.isActive),
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
