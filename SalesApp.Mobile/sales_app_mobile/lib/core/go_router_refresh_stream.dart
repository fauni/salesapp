import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a stream (the AuthBloc state stream) into a [Listenable] so GoRouter
/// re-evaluates its `redirect` whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription =
        stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
