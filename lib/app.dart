import 'package:clinicore_flutter/core/di/injection.dart';
import 'package:clinicore_flutter/core/routes/app_router.dart';
import 'package:clinicore_flutter/core/theme/theme.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/auth/auth_bloc.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/profile/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  /// The ceiling on the OS text-size setting.
  ///
  /// This is a compromise and should be read as one. The design system has
  /// fixed-geometry controls — a 54px button, a 46px chip, a 58px code box —
  /// and past roughly 1.5x the labels stop fitting inside the shapes the brand
  /// is made of. Clamping keeps the app usable for someone who has turned text
  /// size up; NOT clamping would break the layout for them instead, which is
  /// worse.
  ///
  /// The way to raise this is to make those controls grow with their content
  /// rather than to change the number. Most already do (they use `minHeight`,
  /// not `height`); the ones that do not are the reason the ceiling is here.
  static const double _maxTextScale = 1.5;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  /// Both are built ONCE, in `initState`, and that is load-bearing.
  ///
  /// A `GoRouter` created in `build` throws away the whole navigation stack on
  /// every rebuild, and an `AuthBloc` created in `build` would restart session
  /// resolution each time — which, with the router listening to it, is an
  /// infinite loop waiting to happen.
  late final AuthBloc _authBloc = sl<AuthBloc>()..add(const AuthStarted());
  late final AppRouter _appRouter = AppRouter(_authBloc);

  @override
  void dispose() {
    // Registered as a lazy singleton, so it is not disposed here: the locator
    // owns it, and the app is going away anyway.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            previous.isAuthenticated && !current.isAuthenticated,
        listener: (context, state) {
          sl<ProfileBloc>().add(const ProfileReset());
        },
        child: MaterialApp.router(
          title: 'CliniCore',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          // No dark theme, and none inherited from the OS. The palette board
          // defines one set of surfaces with contrast ratios measured against
          // them; a dark variant needs its own measured palette, not an inverted
          // copy. Until that exists, honouring a system dark preference would
          // mean shipping unmeasured colour.
          themeMode: ThemeMode.light,

          // Spanish, and not "whatever the phone is set to". A patient with an
          // English phone still gets a Spanish clinic app, and without these
          // delegates the date picker, the text-selection menu and every native
          // tooltip come out in English inside it.
          locale: const Locale('es'),
          supportedLocales: const <Locale>[Locale('es')],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          routerConfig: _appRouter.router,
          builder: (context, child) {
            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: MainApp._maxTextScale,
              child: child!,
            );
          },
        ),
      ),
    );
  }
}
