import 'package:clinicore_flutter/core/di/injection.dart';
import 'package:clinicore_flutter/core/theme/theme.dart';
import 'package:clinicore_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/login_usecases.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/registration_usecases.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/session_usecases.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/auth/auth_bloc.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/registration/registration_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

/// Registers everything a screen test needs, with a [FakeAuthRepository] in
/// place of the real one.
///
/// Only the repository is faked. The use cases and blocs above it are the REAL
/// ones, which is the point: a test that swaps out the bloc is not testing the
/// bloc, and a test that swaps out the use cases is not testing that the
/// screen wired them up correctly.
///
/// Returns the fake so a test can script it and inspect what it received.
FakeAuthRepository setUpAuthDependencies() {
  final FakeAuthRepository repository = FakeAuthRepository();

  // Tests run in the same isolate one after another, so a leftover
  // registration from the previous test would silently win.
  sl.reset();

  sl.registerSingleton<AuthRepository>(repository);

  sl.registerLazySingleton(() => LoginPatient(sl()));
  sl.registerLazySingleton(() => CanUnlockWithBiometrics(sl()));
  sl.registerLazySingleton(() => UnlockWithBiometrics(sl()));
  sl.registerLazySingleton(() => InitRegistration(sl()));
  sl.registerLazySingleton(() => CompleteRegistration(sl()));
  sl.registerLazySingleton(() => RestoreSession(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  sl.registerFactory<LoginBloc>(
    () => LoginBloc(
      loginPatient: sl(),
      canUnlockWithBiometrics: sl(),
      unlockWithBiometrics: sl(),
    ),
  );
  sl.registerFactory<RegistrationBloc>(
    () => RegistrationBloc(initRegistration: sl(), completeRegistration: sl()),
  );

  return repository;
}

/// Hosts a widget in enough app to render: the real theme, Spanish
/// localisations, and an [AuthBloc] above it.
///
/// The [AuthBloc] is not optional. Every screen that can end a session reads
/// it — the login screen to report one, the profile screen to end one — and
/// without it the test fails with a provider lookup error that says nothing
/// about what is missing.
///
/// NOTE: no `pumpAndSettle` anywhere in these tests. `AppBeam`, `AppLiveDot`
/// and `AppSkeleton` animate forever by design, so it never returns.
Future<AuthBloc> pumpApp(
  WidgetTester tester,
  Widget screen, {
  AuthBloc? authBloc,
}) async {
  final AuthBloc bloc =
      authBloc ?? AuthBloc(restoreSession: sl(), signOut: sl());

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const <Locale>[Locale('es')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: screen,
      ),
    ),
  );
  await tester.pump();

  return bloc;
}
