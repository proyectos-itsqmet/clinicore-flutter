import 'package:clinicore_flutter/core/di/injection.dart';
import 'package:clinicore_flutter/core/theme/theme.dart';
import 'package:clinicore_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/login_usecases.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/password_reset_usecases.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/registration_usecases.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/session_usecases.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/auth/auth_bloc.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/recovery/recovery_bloc.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/registration/registration_bloc.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/appointments_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/booking_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/clinical_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/coverage_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/patient_repository.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/appointments_usecases.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/booking_usecases.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/clinical_usecases.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/coverage_usecases.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/profile_usecases.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/appointments/appointments_bloc.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/booking/booking_bloc.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/coverage/coverage_bloc.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/history/history_bloc.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/password/password_bloc.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/profile/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_home_repositories.dart';

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
  sl.registerLazySingleton(() => VerifyRegistrationOtp(sl()));
  sl.registerLazySingleton(() => CompleteRegistration(sl()));
  sl.registerLazySingleton(() => RestoreSession(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerLazySingleton(() => InitPasswordRecovery(sl()));
  sl.registerLazySingleton(() => VerifyRecoveryOtp(sl()));
  sl.registerLazySingleton(() => ChangePassword(sl()));

  sl.registerFactory<LoginBloc>(
    () => LoginBloc(
      loginPatient: sl(),
      canUnlockWithBiometrics: sl(),
      unlockWithBiometrics: sl(),
    ),
  );
  sl.registerFactory<RegistrationBloc>(
    () => RegistrationBloc(
      initRegistration: sl(),
      verifyRegistrationOtp: sl(),
      completeRegistration: sl(),
    ),
  );
  sl.registerFactory<RecoveryBloc>(
    () => RecoveryBloc(
      initPasswordRecovery: sl(),
      verifyRecoveryOtp: sl(),
      changePassword: sl(),
    ),
  );

  return repository;
}

/// The home feature's doubles, registered together.
class HomeFakes {
  const HomeFakes({
    required this.patient,
    required this.appointments,
    required this.booking,
    required this.clinical,
    required this.coverage,
  });

  final FakePatientRepository patient;
  final FakeAppointmentsRepository appointments;
  final FakeBookingRepository booking;
  final FakeClinicalRepository clinical;
  final FakeCoverageRepository coverage;
}

/// Registers the home feature on top of auth, with fake repositories.
///
/// Calls [setUpAuthDependencies] first and NOT `sl.reset()` itself, which
/// matters: every home screen reads [AuthBloc] to report an expired session, so
/// a locator with only the home half registered fails on the first screen that
/// does. Auth is the floor, not an option.
///
/// Only the REPOSITORIES are faked. The use cases and blocs above them are the
/// real ones — a test that swaps out the bloc is not testing the bloc, and a
/// test that swaps out the use cases is not testing that the screen wired them
/// up.
HomeFakes setUpHomeDependencies() {
  final FakeAuthRepository _ = setUpAuthDependencies();

  final FakePatientRepository patient = FakePatientRepository();
  final FakeAppointmentsRepository appointments = FakeAppointmentsRepository();
  final FakeBookingRepository booking = FakeBookingRepository();
  final FakeClinicalRepository clinical = FakeClinicalRepository();
  final FakeCoverageRepository coverage = FakeCoverageRepository();

  sl.registerSingleton<PatientRepository>(patient);
  sl.registerSingleton<AppointmentsRepository>(appointments);
  sl.registerSingleton<BookingRepository>(booking);
  sl.registerSingleton<ClinicalRepository>(clinical);
  sl.registerSingleton<CoverageRepository>(coverage);

  sl.registerLazySingleton(() => GetMyProfile(sl()));
  sl.registerLazySingleton(() => UpdateMyContact(sl()));
  sl.registerLazySingleton(() => ChangeMyPassword(sl()));
  sl.registerLazySingleton(() => GetMyAppointments(sl()));
  sl.registerLazySingleton(() => CancelAppointment(sl()));
  sl.registerLazySingleton(() => WatchTurnUpdates(sl()));
  sl.registerLazySingleton(() => GetEstablishments(sl()));
  sl.registerLazySingleton(() => GetServicesWithDoctors(sl()));
  sl.registerLazySingleton(() => GetFreeSchedules(sl()));
  sl.registerLazySingleton(() => BookSlot(sl()));
  sl.registerLazySingleton(() => GetMyEncounters(sl()));
  sl.registerLazySingleton(() => GetMyPrescriptions(sl()));
  sl.registerLazySingleton(() => GetMyCoverages(sl()));

  // A FACTORY here, unlike production, and that is the point: the real app
  // registers ProfileBloc as a lazy singleton so two screens share one fetch.
  // In tests that would carry one test's profile — and its scripted failure —
  // into the next one, because `sl.reset()` disposes the registration but the
  // shared instance is exactly what a stale test wants to reuse.
  sl.registerFactory<ProfileBloc>(
    () => ProfileBloc(getMyProfile: sl(), updateMyContact: sl()),
  );

  sl.registerFactoryParam<AppointmentsBloc, AppointmentScope, void>(
    (AppointmentScope scope, _) => AppointmentsBloc(
      getMyAppointments: sl(),
      cancelAppointment: sl(),
      watchTurnUpdates: sl(),
      scope: scope,
    ),
  );

  sl.registerFactory<BookingBloc>(
    () => BookingBloc(
      getEstablishments: sl(),
      getServicesWithDoctors: sl(),
      getFreeSchedules: sl(),
      bookSlot: sl(),
    ),
  );

  sl.registerFactory<HistoryBloc>(
    () => HistoryBloc(
      getMyAppointments: sl(),
      getMyEncounters: sl(),
      getMyPrescriptions: sl(),
    ),
  );

  sl.registerFactory<CoverageBloc>(
    () => CoverageBloc(getMyCoverages: sl()),
  );

  sl.registerFactory<PasswordBloc>(
    () => PasswordBloc(changeMyPassword: sl()),
  );

  return HomeFakes(
    patient: patient,
    appointments: appointments,
    booking: booking,
    clinical: clinical,
    coverage: coverage,
  );
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
