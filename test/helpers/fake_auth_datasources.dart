import 'package:clinicore_flutter/core/error/exceptions.dart';
import 'package:clinicore_flutter/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:clinicore_flutter/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:clinicore_flutter/features/auth/data/datasources/biometric_data_source.dart';
import 'package:clinicore_flutter/features/auth/data/models/auth_response_model.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/patient_registration.dart';

/// Hand-written doubles for the auth feature's DATA-layer interfaces.
///
/// Same reasoning as [FakeAuthRepository]: no Dio sits at this boundary, so
/// there is nothing here that needs a mocking package or a real network
/// stack. These exist to test [AuthRepositoryImpl] itself — the translation
/// layer between the data sources and the domain — which none of this
/// project's existing tests exercise directly; the bloc tests all go through
/// `FakeAuthRepository` instead, one layer above this one.
///
/// Only [logout] and [clear] are actually driven by a test today. Everything
/// else throws [UnimplementedError] on purpose: a test that reaches one of
/// them is exercising something this double was never meant to answer, and a
/// loud failure beats a silently wrong default.
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  /// Thrown by [logout] when set. `null` (the default) means it succeeds.
  AppException? logoutError;

  int logoutCallCount = 0;

  @override
  Future<void> logout() async {
    logoutCallCount++;
    final AppException? error = logoutError;
    if (error != null) throw error;
  }

  @override
  Future<RemoteAuthResult> loginPatient({
    String? email,
    String? cedula,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> initRegistration({
    required String email,
    required String cedula,
  }) => throw UnimplementedError();

  @override
  Future<String> verifyRegistrationOtp({required String otp}) =>
      throw UnimplementedError();

  @override
  Future<RemoteAuthResult> completeRegistration(
    PatientRegistration registration,
  ) => throw UnimplementedError();

  @override
  Future<String> initPasswordRecovery({required String email}) =>
      throw UnimplementedError();

  @override
  Future<String> verifyRecoveryOtp({required String otp}) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String password,
    required String repeatedPassword,
  }) => throw UnimplementedError();
}

class FakeAuthLocalDataSource implements AuthLocalDataSource {
  int clearCallCount = 0;
  StoredSession? session;

  @override
  Future<void> clear() async {
    clearCallCount++;
    session = null;
  }

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session?.token;

  @override
  Future<void> saveSession({
    required String token,
    required AuthResponseModel user,
  }) async {
    session = StoredSession(token: token, user: user);
  }

  @override
  Future<void> saveTokenOnly(String token) async {}
}

class FakeBiometricDataSource implements BiometricDataSource {
  bool available = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> authenticate() async {}
}
