import 'package:clinicore_flutter/core/routes/app_path.dart';
import 'package:clinicore_flutter/core/routes/path_name.dart';
import 'package:clinicore_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static GoRouter get router => _goRouter;
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter _goRouter = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppPath.loginScreen,
    routes: [
      GoRoute(
        path: AppPath.loginScreen,
        name: PathName.loginScreen,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: AppPath.homeScreen,
        name: PathName.homeScreen,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => HomeScreen(),
      ),
    ],
  );
}
