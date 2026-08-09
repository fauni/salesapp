import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/customers/customers_bloc.dart';
import '../../../data/models/customer.dart';
import '../../widgets/search_field.dart';
import '../../widgets/status_message.dart';
import 'customer_tile.dart';

/// Reusable search + live-filtered list of customers. Used by both the Clientes
/// section and the new-order client picker; the caller decides what happens on
/// tap via [onSelect].
class CustomerSearchView extends StatelessWidget {
  final void Function(Customer customer) onSelect;

  const CustomerSearchView({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchField(
            hintText: 'Buscar cliente por nombre o código',
            onChanged: (q) =>
                context.read<CustomersBloc>().add(CustomersSearchChanged(q)),
          ),
        ),
        Expanded(
          child: BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              switch (state.status) {
                case CustomersStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case CustomersStatus.failure:
                  return StatusMessage(
                    icon: Icons.error_outline_rounded,
                    title: state.error ?? 'No se pudieron cargar los clientes',
                    actionLabel: 'Reintentar',
                    onAction: () => context
                        .read<CustomersBloc>()
                        .add(CustomersSearchChanged(state.query)),
                  );
                case CustomersStatus.success:
                  if (state.customers.isEmpty) {
                    return StatusMessage(
                      icon: Icons.person_search_outlined,
                      title: state.query.isEmpty
                          ? 'No hay clientes'
                          : 'Sin resultados para "${state.query}"',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: state.customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final customer = state.customers[i];
                      return CustomerTile(
                        customer: customer,
                        onTap: () => onSelect(customer),
                      );
                    },
                  );
              }
            },
          ),
        ),
      ],
    );
  }
}
