import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_scaffold.dart';
import 'widgets/customer_search_view.dart';

/// New order — step 1: pick the client. Selecting a customer starts the order
/// flow (item catalog arrives in Etapa 4). Reached from the FAB (pushed → back
/// arrow) or the drawer (root → hamburger).
class ClientPickerScreen extends StatelessWidget {
  const ClientPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Nuevo pedido — Cliente',
      onBack: context.canPop() ? () => context.pop() : null,
      body: CustomerSearchView(
        onSelect: (customer) => context.push(
          '/new-order/catalog',
          extra: customer,
        ),
      ),
    );
  }
}
