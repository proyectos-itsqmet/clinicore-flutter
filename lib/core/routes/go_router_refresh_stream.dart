import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns a [Stream] into the [Listenable] that `GoRouter.refreshListenable`
/// wants.
///
/// This is the standard bridge between a bloc and go_router, and it is needed
/// because the two have different notification models: a bloc emits states, a
/// router wants to be told "re-evaluate your redirects now".
///
/// The first state is consumed eagerly in the constructor rather than
/// notified. That detail matters: the bloc's current state is already visible
/// to `redirect` when the router is built, so notifying for it would trigger a
/// redundant redirect pass before the app has drawn a frame.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
