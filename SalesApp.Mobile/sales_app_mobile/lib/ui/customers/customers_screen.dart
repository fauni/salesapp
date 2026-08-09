import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_scaffold.dart';
import 'widgets/customer_search_view.dart';

/// Drawer section "Clientes": browse/search customers, tap to see the detail
/// with contacts.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Clientes',
      body: CustomerSearchView(
        onSelect: (customer) =>
            context.push('/customers/${customer.code}', extra: customer),
      ),
    );
  }
}
