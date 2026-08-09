import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';

/// Temporary top-level screen for drawer sections not built yet. Keeps the
/// shell/drawer navigation demonstrable during Etapa 0.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String stage;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.text3),
            const SizedBox(height: 12),
            Text('Próximamente',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(stage,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.text2)),
          ],
        ),
      ),
    );
  }
}
