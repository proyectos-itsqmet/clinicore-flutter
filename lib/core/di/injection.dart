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
    () => RegistrationBloc(initRegistration: sl(), completeRegistration: sl()),
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
}
