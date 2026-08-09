import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Screen transition from DESIGN.md: fade in + slide up ~6px, 260ms, ease-out.
/// This app's navigation isn't a linear stack, so we avoid Material's default
/// slide-from-right.
CustomTransitionPage<void> appPage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          return Opacity(
            opacity: curved.value,
            child: Transform.translate(
              offset: Offset(0, 6 * (1 - curved.value)), // 6px up
              child: child,
            ),
          );
        },
      );
    },
  );
}
