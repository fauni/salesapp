import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Large search bar (DESIGN.md): white rounded pill, 46px tall, leading search
/// icon, optional trailing action (e.g. a scan chip on the item catalog).
class SearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final bool autofocus;

  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Buscar',
    this.trailing,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.text3, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              autofocus: autofocus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(color: AppColors.text3),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
