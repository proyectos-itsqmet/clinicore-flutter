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

  static const double _maxTextScale = 1.5;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AuthBloc _authBloc = sl<AuthBloc>()..add(const AuthStarted());
  late final AppRouter _appRouter = AppRouter(_authBloc);

  @override
  void dispose() {
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
          themeMode: ThemeMode.light,
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
