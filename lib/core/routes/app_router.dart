import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/blocs/auth/auth_bloc.dart';
import '../../features/auth/presentation/blocs/recovery/recovery_bloc.dart';
import '../../features/auth/presentation/blocs/registration/registration_bloc.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/recovery_code_screen.dart';
import '../../features/auth/presentation/screens/register_profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/home/domain/entities/history_entry.dart';
import '../../features/home/presentation/screens/appointments_screen.dart';
import '../../features/home/presentation/screens/booking_screen.dart';
import '../../features/home/presentation/screens/change_password_screen.dart';
import '../../features/home/presentation/screens/history_detail_screen.dart';
import '../../features/home/presentation/screens/history_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/personal_info_screen.dart';
import '../../features/home/presentation/screens/privacy_screen.dart';
import '../../features/home/presentation/screens/profile_screen.dart';
import '../../features/home/presentation/screens/terms_screen.dart';
import '../di/injection.dart';
import 'app_path.dart';
import 'go_router_refresh_stream.dart';
import 'path_name.dart';

/// The app's router.
///
/// Three layers, and each boundary is load-bearing:
///
/// * **The auth guard** ([_redirect]) decides, for every navigation, whether
///   the target is reachable with the session the app currently has. It is the
///   only place that decision is made — screens never check "am I logged in?"
///   and then push somewhere else, because a guard spread across twelve
///   screens is a guard with eleven holes.
/// * **The registration `ShellRoute`** owns one [RegistrationBloc] for all
///   three sign-up steps. The email and cedula from step 1 have to survive two
///   pushes, and the server rejects step 3 if the email does not match.
/// * **The `StatefulShellRoute`** owns the four tabs, each with its own
///   navigator so their back stacks are independent.
class AppRouter {
  AppRouter(this._authBloc);

  final AuthBloc _authBloc;

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  // One navigator per tab. Without these, all four branches share a stack and
  // the back button walks across tabs.
  static final _bookingNavigatorKey = GlobalKey<NavigatorState>();
  static final _appointmentsNavigatorKey = GlobalKey<NavigatorState>();
  static final _historyNavigatorKey = GlobalKey<NavigatorState>();
  static final _profileNavigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppPath.splashScreen,

    // Re-runs [_redirect] whenever the session changes. This is what makes
    // login, sign-out and an expired token all navigate by themselves: no
    // screen pushes a route on success, it just reports the new session and
    // the router does the rest.
    refreshListenable: GoRouterRefreshStream(_authBloc.stream),
    redirect: _redirect,

    routes: <RouteBase>[
      GoRoute(
        path: AppPath.splashScreen,
        name: PathName.splashScreen,
        builder: (context, state) => const SplashScreen(),
      ),

      // ======================================================
      // AUTH
      // ======================================================
      GoRoute(
        path: AppPath.loginScreen,
        name: PathName.loginScreen,
        builder: (context, state) => const LoginScreen(),
      ),
      // ======================================================
      // PASSWORD RECOVERY — one bloc, three steps
      // ======================================================
      //
      // Same shape as registration, for the same reason: the address from step
      // 1 has to survive two pushes, and each step authenticates with the
      // short-lived token the previous one issued.
      ShellRoute(
        builder: (context, state, child) => BlocProvider<RecoveryBloc>(
          create: (_) => sl<RecoveryBloc>(),
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: AppPath.forgotPasswordScreen,
            name: PathName.forgotPasswordScreen,
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: AppPath.recoveryCodeScreen,
            name: PathName.recoveryCodeScreen,
            builder: (context, state) => const RecoveryCodeScreen(),
          ),
          GoRoute(
            path: AppPath.recoveryPasswordScreen,
            name: PathName.recoveryPasswordScreen,
            builder: (context, state) => const ResetPasswordScreen(),
          ),
        ],
      ),

      // ======================================================
      // REGISTRATION — one bloc, three steps
      // ======================================================
      ShellRoute(
        builder: (context, state, child) => BlocProvider<RegistrationBloc>(
          create: (_) => sl<RegistrationBloc>(),
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: AppPath.registerScreen,
            name: PathName.registerScreen,
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: AppPath.registerVerificationScreen,
            name: PathName.registerVerificationScreen,
            builder: (context, state) => const OtpScreen(),
          ),
          GoRoute(
            path: AppPath.registerProfileScreen,
            name: PathName.registerProfileScreen,
            builder: (context, state) => const RegisterProfileScreen(),
          ),
        ],
      ),

      // ======================================================
      // PUBLIC DOCUMENTS — readable with or without a session
      // ======================================================
      GoRoute(
        path: AppPath.termsScreen,
        name: PathName.termsScreen,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: AppPath.privacyScreen,
        name: PathName.privacyScreen,
        builder: (context, state) => const PrivacyScreen(),
      ),

      // ======================================================
      // AUTHENTICATED
      // ======================================================
      GoRoute(
        path: AppPath.personalInfoScreen,
        name: PathName.personalInfoScreen,
        builder: (context, state) => const PersonalInfoScreen(),
      ),

      GoRoute(
        path: AppPath.changePasswordScreen,
        name: PathName.changePasswordScreen,
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      // The visit travels in `extra` rather than in the path: it is an object
      // this app JOINED from three endpoints, not a resource with an id, and
      // re-fetching it here would put a second audited clinical read into the
      // server's log for a card the patient already loaded. `extra` is
      // in-memory only, so a cold start on this URL arrives with null — see
      // `HistoryDetailScreen`, which renders that as what it is instead of
      // casting and crashing.
      GoRoute(
        path: AppPath.historyDetailScreen,
        name: PathName.historyDetailScreen,
        builder: (context, state) =>
            HistoryDetailScreen(entry: state.extra as HistoryEntry?),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeScreen(shell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _bookingNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppPath.bookingScreen,
                name: PathName.bookingScreen,
                builder: (context, state) => const BookingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _appointmentsNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppPath.appointmentsScreen,
                name: PathName.appointmentsScreen,
                builder: (context, state) => const AppointmentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _historyNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppPath.historyScreen,
                name: PathName.historyScreen,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppPath.profileScreen,
                name: PathName.profileScreen,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// The auth guard.
  ///
  /// Returning `null` means "this location is fine". Returning a path means
  /// "go there instead". The order of the four checks below is the logic:
  ///
  /// 1. The legal documents are always reachable — a patient must be able to
  ///    read the terms before agreeing to them, which is before they have an
  ///    account.
  /// 2. While the session is still unknown, everything funnels to the splash.
  ///    This is what stops the login form flashing at a patient who is already
  ///    signed in.
  /// 3. No session: only the auth flow is reachable.
  /// 4. A session: the auth flow is NOT reachable, so the back button after
  ///    logging in cannot walk back into the login form.
  String? _redirect(BuildContext context, GoRouterState state) {
    final String location = state.matchedLocation;
    final AuthState auth = _authBloc.state;

    if (AppPath.publicPaths.contains(location)) return null;

    if (!auth.isResolved) {
      return location == AppPath.splashScreen ? null : AppPath.splashScreen;
    }

    final bool onAuthFlow = AppPath.isAuthFlow(location);

    if (!auth.isAuthenticated) {
      // The splash is part of the auth flow but is not a destination once the
      // session has resolved — otherwise the app sits on it forever.
      final bool canStay = onAuthFlow && location != AppPath.splashScreen;
      return canStay ? null : AppPath.loginScreen;
    }

    return onAuthFlow ? AppPath.bookingScreen : null;
  }
}
