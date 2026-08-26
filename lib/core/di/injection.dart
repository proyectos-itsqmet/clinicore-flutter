import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/biometric_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecases.dart';
import '../../features/auth/domain/usecases/password_reset_usecases.dart';
import '../../features/auth/domain/usecases/registration_usecases.dart';
import '../../features/auth/domain/usecases/session_usecases.dart';
import '../../features/auth/presentation/blocs/auth/auth_bloc.dart';
import '../../features/auth/presentation/blocs/login/login_bloc.dart';
import '../../features/auth/presentation/blocs/recovery/recovery_bloc.dart';
import '../../features/auth/presentation/blocs/registration/registration_bloc.dart';
import '../../features/home/data/datasources/appointments_remote_data_source.dart';
import '../../features/home/data/datasources/booking_remote_data_source.dart';
import '../../features/home/data/datasources/clinical_remote_data_source.dart';
import '../../features/home/data/datasources/coverage_remote_data_source.dart';
import '../../features/home/data/datasources/patient_remote_data_source.dart';
import '../../features/home/data/datasources/turn_updates_remote_data_source.dart';
import '../../features/home/data/repositories/appointments_repository_impl.dart';
import '../../features/home/data/repositories/booking_repository_impl.dart';
import '../../features/home/data/repositories/clinical_repository_impl.dart';
import '../../features/home/data/repositories/coverage_repository_impl.dart';
import '../../features/home/data/repositories/patient_repository_impl.dart';
import '../../features/home/domain/repositories/appointments_repository.dart';
import '../../features/home/domain/repositories/booking_repository.dart';
import '../../features/home/domain/repositories/clinical_repository.dart';
import '../../features/home/domain/repositories/coverage_repository.dart';
import '../../features/home/domain/repositories/patient_repository.dart';
import '../../features/home/domain/usecases/appointments_usecases.dart';
import '../../features/home/domain/usecases/booking_usecases.dart';
import '../../features/home/domain/usecases/clinical_usecases.dart';
import '../../features/home/domain/usecases/coverage_usecases.dart';
import '../../features/home/domain/usecases/profile_usecases.dart';
import '../../features/home/presentation/blocs/appointments/appointments_bloc.dart';
import '../../features/home/presentation/blocs/booking/booking_bloc.dart';
import '../../features/home/presentation/blocs/coverage/coverage_bloc.dart';
import '../../features/home/presentation/blocs/history/history_bloc.dart';
import '../../features/home/presentation/blocs/password/password_bloc.dart';
import '../../features/home/presentation/blocs/profile/profile_bloc.dart';
import '../network/dio_client.dart';
import '../network/token_store.dart';

/// The service locator.
final GetIt sl = GetIt.instance;

/// Wires everything, outermost layer first.
///
/// Registration style is not arbitrary:
///
/// * **`registerLazySingleton`** for anything stateless and shared — Dio, the
///   data sources, the repository, the use cases. One instance, created on
///   first use.
/// * **`registerFactory`** for blocs that own a screen's lifecycle
///   ([LoginBloc], [RegistrationBloc]). A singleton bloc would carry the last
///   attempt's error into the next visit, and a closed bloc cannot be
///   reopened — this is the single most common get_it + bloc mistake.
/// * **`registerLazySingleton`** for [AuthBloc], which is the exception: it
///   holds session state for the whole app and the router listens to it, so
///   there must be exactly one and it must outlive every screen.
Future<void> configureDependencies() async {
  // ==========================================================
  // EXTERNAL
  // ==========================================================
  // No `aOptions`: the Android `encryptedSharedPreferences` flag is deprecated
  // (Google retired Jetpack Security) and ignored in this version. See
  // `SecureTokenStore`.
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(iOptions: SecureTokenStore.iosOptions),
  );

  sl.registerLazySingleton<LocalAuthentication>(LocalAuthentication.new);

  // ==========================================================
  // CORE
  // ==========================================================
  sl.registerLazySingleton<TokenStore>(() => SecureTokenStore(sl()));

  // Depends on TokenStore, because the auth interceptor reads the token on
  // every request. Registered after it, for the same reason.
  sl.registerLazySingleton<Dio>(() => DioClient.create(sl()));

  // ==========================================================
  // AUTH — data
  // ==========================================================
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(tokenStore: sl(), storage: sl()),
  );

  sl.registerLazySingleton<BiometricDataSource>(
    () => BiometricDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remote: sl(), local: sl(), biometrics: sl()),
  );

  // ==========================================================
  // AUTH — domain
  // ==========================================================
  sl.registerLazySingleton(() => LoginPatient(sl()));
  sl.registerLazySingleton(() => CanUnlockWithBiometrics(sl()));
  sl.registerLazySingleton(() => UnlockWithBiometrics(sl()));
  sl.registerLazySingleton(() => InitRegistration(sl()));
  sl.registerLazySingleton(() => VerifyRegistrationOtp(sl()));
  sl.registerLazySingleton(() => CompleteRegistration(sl()));
  sl.registerLazySingleton(() => RestoreSession(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  // Password recovery — the three steps now exist on the server.
  sl.registerLazySingleton(() => InitPasswordRecovery(sl()));
  sl.registerLazySingleton(() => VerifyRecoveryOtp(sl()));
  sl.registerLazySingleton(() => ChangePassword(sl()));

  // ==========================================================
  // AUTH — presentation
  // ==========================================================

  // One for the whole app. The router holds a reference to it.
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(restoreSession: sl(), signOut: sl()),
  );

  // A fresh one per screen. See the note above about factories.
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

  // A factory, like the other flow blocs: a recovery that was abandoned
  // halfway must not resume with a dead flash token the next time someone taps
  // "Olvidaste tu contrasena?".
  sl.registerFactory<RecoveryBloc>(
    () => RecoveryBloc(
      initPasswordRecovery: sl(),
      verifyRecoveryOtp: sl(),
      changePassword: sl(),
    ),
  );

  // ==========================================================
  // HOME — data
  // ==========================================================
  sl.registerLazySingleton<PatientRemoteDataSource>(
    () => PatientRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<AppointmentsRemoteDataSource>(
    () => AppointmentsRemoteDataSourceImpl(sl()),
  );

  // Depends on TokenStore, same as Dio's own AuthInterceptor — see the
  // class doc for why the socket authenticates itself the same way.
  sl.registerLazySingleton<TurnUpdatesRemoteDataSource>(
    () => TurnUpdatesRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<PatientRepository>(() => PatientRepositoryImpl(sl()));

  sl.registerLazySingleton<AppointmentsRepository>(
    () => AppointmentsRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<BookingRepository>(() => BookingRepositoryImpl(sl()));

  // "Historial"'s two extra reads — see `HistoryBloc` for why they are
  // fetched and joined there rather than folded into `AppointmentsRepository`.
  sl.registerLazySingleton<ClinicalRemoteDataSource>(
    () => ClinicalRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<ClinicalRepository>(
    () => ClinicalRepositoryImpl(sl()),
  );

  // "Mi informacion"'s Cobertura group.
  sl.registerLazySingleton<CoverageRemoteDataSource>(
    () => CoverageRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<CoverageRepository>(
    () => CoverageRepositoryImpl(sl()),
  );

  // ==========================================================
  // HOME — domain
  // ==========================================================
  sl.registerLazySingleton(() => GetMyProfile(sl()));
  sl.registerLazySingleton(() => UpdateMyContact(sl()));
  // `ChangeMyPassword`, not `ChangePassword` — the recovery flow already owns
  // that name and this file imports both. See the use case's own doc.
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

  // ==========================================================
  // HOME — presentation
  // ==========================================================

  // A LAZY SINGLETON, unlike the form blocs, and it is the same exception
  // AuthBloc gets: two screens read the same record ("Mi perfil" shows the
  // name and cedula, "Mi informacion" shows all of it), and a factory would
  // refetch the profile every time the patient navigates between them. There
  // is no stale form error to carry into a second visit — the state is a
  // record, not a submission.
  sl.registerLazySingleton<ProfileBloc>(
    () => ProfileBloc(getMyProfile: sl(), updateMyContact: sl()),
  );

  // A FACTORY, and parameterised by SCOPE: each list is its own instance, so
  // the segmented control swaps blocs instead of refetching every time the
  // patient looks back and forth between "Proximas" and "Pasadas".
  //
  // A factory and not a singleton for the usual reason plus one specific to a
  // clinic: on a shared phone, a singleton would carry one patient's
  // appointments into the next patient's session.
  sl.registerFactoryParam<AppointmentsBloc, AppointmentScope, void>(
    (AppointmentScope scope, _) => AppointmentsBloc(
      getMyAppointments: sl(),
      cancelAppointment: sl(),
      watchTurnUpdates: sl(),
      scope: scope,
    ),
  );

  // A factory, like the auth flow blocs: "Agendar" is a multi-step wizard,
  // and a singleton would resume with a slot the patient chose an hour ago —
  // which by then may belong to somebody else.
  sl.registerFactory<BookingBloc>(
    () => BookingBloc(
      getEstablishments: sl(),
      getServicesWithDoctors: sl(),
      getFreeSchedules: sl(),
      bookSlot: sl(),
    ),
  );

  // A factory: "Historial" is its own screen, fetched once per visit — see
  // the bloc's class doc for why it is not folded into `AppointmentsBloc`.
  sl.registerFactory<HistoryBloc>(
    () => HistoryBloc(
      getMyAppointments: sl(),
      getMyEncounters: sl(),
      getMyPrescriptions: sl(),
    ),
  );

  // A factory: only "Mi informacion" reads it, so there is no cross-screen
  // fetch for a singleton to share — unlike `ProfileBloc`.
  sl.registerFactory<CoverageBloc>(
    () => CoverageBloc(getMyCoverages: sl()),
  );

  // A FACTORY even though `ProfileBloc` next to it is a singleton, and the
  // difference is the point: this one holds a SUBMISSION, not a record. A
  // rejected password left in a shared singleton would still be on screen
  // under "Mi informacion" the next time the patient opened it.
  sl.registerFactory<PasswordBloc>(
    () => PasswordBloc(changeMyPassword: sl()),
  );
}
