import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/contacts/contacts_bloc.dart';
import '../../blocs/customer_detail/customer_detail_bloc.dart';
import '../../data/models/customer.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_message.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String code;

  /// Passed via router `extra` when navigated from a list; may be null on a
  /// cold deep-link, in which case only the code is shown in the header.
  final Customer? customer;

  const CustomerDetailScreen({super.key, required this.code, this.customer});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: customer?.name ?? code,
      onBack: () => context.pop(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _header(context),
          const SizedBox(height: 16),
          _sectionLabel('DATOS COMERCIALES'),
          const SizedBox(height: 8),
          const _CommercialSection(),
          const SizedBox(height: 16),
          _sectionLabel('CONTACTOS'),
          const SizedBox(height: 8),
          const _ContactsSection(),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = customer;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(source: c?.name ?? code, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c?.name ?? code,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text1,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(code,
                        style: GoogleFonts.inter(
                            color: AppColors.text2, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (c != null) ...[
            const SizedBox(height: 12),
            _row(Icons.phone_outlined, c.phone),
            _row(Icons.smartphone_outlined, c.cellular),
            _row(Icons.email_outlined, c.email),
            _row(Icons.badge_outlined, c.federalTaxId),
            _row(Icons.attach_money_outlined, c.currency),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

Widget _sectionLabel(String text) => Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: AppColors.text3,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.6,
      ),
    );

/// Price list + payment terms, resolved to names by the backend. Shown
/// read-only — these don't drive line pricing (that stays out of scope).
class _CommercialSection extends StatelessWidget {
  const _CommercialSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerDetailBloc, CustomerDetailState>(
      builder: (context, state) {
        switch (state.status) {
          case CustomerDetailStatus.loading:
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          case CustomerDetailStatus.failure:
            return StatusMessage(
              icon: Icons.error_outline_rounded,
              title: state.error ?? 'No se pudieron cargar los datos comerciales',
              actionLabel: 'Reintentar',
              onAction: () => context
                  .read<CustomerDetailBloc>()
                  .add(const CustomerDetailRefreshed()),
            );
          case CustomerDetailStatus.success:
            final d = state.detail!;
            return SectionCard(
              child: Column(
                children: [
                  _kv(Icons.sell_outlined, 'Lista de precios',
                      d.priceListName, d.priceListNum),
                  const SizedBox(height: 12),
                  _kv(Icons.event_note_outlined, 'Condición de pago',
                      d.paymentTermsGroupName, d.paymentTermsGroupCode),
                ],
              ),
            );
        }
      },
    );
  }

  /// One label/value row. Falls back to the raw code when the name is missing,
  /// and to a dash when there's nothing at all.
  Widget _kv(IconData icon, String label, String? name, int? code) {
    final value = (name != null && name.isNotEmpty)
        ? name
        : (code != null && code > 0 ? '#$code' : '—');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.text3),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      color: AppColors.text3, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(
                      color: AppColors.text1,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactsSection extends StatelessWidget {
  const _ContactsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContactsBloc, ContactsState>(
      builder: (context, state) {
        switch (state.status) {
          case ContactsStatus.loading:
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          case ContactsStatus.failure:
            return StatusMessage(
              icon: Icons.error_outline_rounded,
              title: state.error ?? 'No se pudieron cargar los contactos',
              actionLabel: 'Reintentar',
              onAction: () =>
                  context.read<ContactsBloc>().add(const ContactsRefreshed()),
            );
          case ContactsStatus.success:
            if (state.contacts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: StatusMessage(
                  icon: Icons.contacts_outlined,
                  title: 'Este cliente no tiene contactos',
                ),
              );
            }
            return SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < state.contacts.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.lineSoft),
                    _ContactRow(state.contacts[i]),
                  ],
                ],
              ),
            );
        }
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  final CustomerContact contact;
  const _ContactRow(this.contact);

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if ((contact.position ?? '').isNotEmpty) contact.position,
      if ((contact.mobilePhone ?? '').isNotEmpty) contact.mobilePhone,
      if ((contact.phone ?? '').isNotEmpty) contact.phone,
      if ((contact.email ?? '').isNotEmpty) contact.email,
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text1,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          color: AppColors.text2, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (!contact.active)
            Text('INACTIVO',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text3,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.4,
                )),
        ],
      ),
    );
  }
}
