import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/patient_registration.dart';
import '../models/auth_request_models.dart';
import '../models/auth_response_model.dart';

/// One authenticated exchange with the server, token included.
class RemoteAuthResult {
  const RemoteAuthResult({required this.response, required this.token});

  final AuthResponseModel response;
  final String token;
}

/// Talks to `/auth` on the QMS backend.
///
/// ## The token arrives three different ways
///
/// This is the single most surprising thing about this API, and it is not a
/// mistake in the client:
///
/// | endpoint                         | where the token is |
/// |----------------------------------|--------------------|
/// | `mobile/login-patient`           | `Authorization` response header |
/// | `init-registration-patient`      | `Set-Cookie: jwt=...` (300s) |
/// | `register-patient`               | `Set-Cookie: jwt=...` (24h) |
/// | `recover-password/init`          | `Set-Cookie: jwt=...` (300s) |
/// | `recover-password/verify-otp`    | `Set-Cookie: jwt=...` (600s) |
///
/// **Only login got a `/mobile/` variant.** Everything else was written for the
/// Angular app, where the browser stores the cookie invisibly — so a native
/// client has to read `Set-Cookie` by hand. That is what [_tokenFromSetCookie]
/// is for, and why it is not optional.
///
/// Sending those tokens BACK is the mirror image of the same problem, and it is
/// solved in `AuthInterceptor`: `JwtValidator.recoverToken` reads the `jwt`
/// cookie and never looks at `Authorization`, so the interceptor sends both.
abstract interface class AuthRemoteDataSource {
  Future<RemoteAuthResult> loginPatient({
    String? email,
    String? cedula,
    required String password,
  });

  /// Returns the 300-second flash token that [completeRegistration] needs.
  Future<String> initRegistration({
    required String email,
    required String cedula,
  });

  /// Registration step 2: checks the mailed code.
  ///
  /// Returns a fresh 300-second token carrying `ROLE_REGISTER_VERIFIED`, which
  /// replaces step 1's `ROLE_OTP_PENDING` one.
  ///
  /// Swapping the token is safe for step 3: `/auth/register-patient` has no
  /// `hasAuthority` matcher in `GlobalConfig` and `completeRegistration` only
  /// compares `auth.getName()` with the submitted email. Both tokens carry the
  /// same subject, so the new one still authenticates step 3 — the new
  /// authority exists so the server CAN start requiring it later.
  Future<String> verifyRegistrationOtp({required String otp});

  Future<RemoteAuthResult> completeRegistration(
    PatientRegistration registration,
  );

  /// Recovery step 1. Returns the 300-second `ROLE_OTP_PENDING` token that
  /// [verifyRecoveryOtp] authenticates with.
  Future<String> initPasswordRecovery({required String email});

  /// Recovery step 2. Returns the 600-second `ROLE_CHANGE_PASSWORD` token that
  /// [changePassword] authenticates with.
  Future<String> verifyRecoveryOtp({required String otp});

  /// Recovery step 3. Nothing to return: the server clears the cookie and the
  /// patient signs in again with the new password.
  Future<void> changePassword({
    required String password,
    required String repeatedPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<RemoteAuthResult> loginPatient({
    String? email,
    String? cedula,
    required String password,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.loginPatientMobile,
        data: LoginRequestModel(
          email: email,
          cedula: cedula,
          password: password,
        ).toJson(),
      );

      final String? token = _tokenFromAuthorizationHeader(response);
      if (token == null) {
        // A 200 with no token means the mobile endpoint changed shape. Failing
        // loudly here is better than storing an empty token and getting 401s
        // on every subsequent screen with no clue why.
        throw const ServerException(
          message: 'El servidor no devolvio la sesion.',
          data: 'missing Authorization header on mobile/login-patient',
        );
      }

      return RemoteAuthResult(
        response: AuthResponseModel.fromJson(_asMap(response.data)),
        token: token,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<String> initRegistration({
    required String email,
    required String cedula,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.initRegistrationPatient,
        data: InitRegistrationRequestModel(
          email: email,
          cedula: cedula,
        ).toJson(),
      );

      final String? token = _tokenFromSetCookie(response);
      if (token == null) {
        throw const ServerException(
          message: 'No pudimos iniciar el registro. Intenta de nuevo.',
          data: 'missing jwt cookie on init-registration-patient',
        );
      }
      return token;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<RemoteAuthResult> completeRegistration(
    PatientRegistration registration,
  ) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.registerPatient,
        data: PatientRegistrationRequestModel(registration).toJson(),
      );

      // The 24h token replaces the flash token. If the cookie is missing we
      // still have a registered patient, so fall back to keeping them signed
      // in with whatever the flash token was rather than losing the account.
      final String? token = _tokenFromSetCookie(response);

      return RemoteAuthResult(
        response: AuthResponseModel.fromJson(_asMap(response.data)),
        token: token ?? '',
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<String> initPasswordRecovery({required String email}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.recoverPasswordInit,
        data: RecoverPasswordInitRequestModel(email: email).toJson(),
      );

      final String? token = _tokenFromSetCookie(response);
      if (token == null) {
        // A 200 with no cookie means the code was mailed but the client has no
        // way to prove step 1 happened, so step 2 would 401. Failing here says
        // that; carrying on would strand the patient on the code screen.
        throw const ServerException(
          message: 'No pudimos iniciar la recuperacion. Intenta de nuevo.',
          data: 'missing jwt cookie on recover-password/init',
        );
      }
      return token;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<String> verifyRegistrationOtp({required String otp}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.verifyOtp,
        data: VerifyOtpRequestModel(otp: otp).toJson(),
      );

      final String? token = _tokenFromSetCookie(response);
      if (token == null) {
        throw const ServerException(
          message: 'No pudimos verificar el codigo. Intenta de nuevo.',
          data: 'missing jwt cookie on auth/verify-otp',
        );
      }
      return token;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<String> verifyRecoveryOtp({required String otp}) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.recoverPasswordVerifyOtp,
        data: VerifyOtpRequestModel(otp: otp).toJson(),
      );

      final String? token = _tokenFromSetCookie(response);
      if (token == null) {
        throw const ServerException(
          message: 'No pudimos verificar el codigo. Intenta de nuevo.',
          data: 'missing jwt cookie on recover-password/verify-otp',
        );
      }
      return token;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> changePassword({
    required String password,
    required String repeatedPassword,
  }) async {
    try {
      await _dio.post<dynamic>(
        ApiEndpoints.recoverPasswordChange,
        data: ChangePasswordRequestModel(
          password: password,
          repeatedPassword: repeatedPassword,
        ).toJson(),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// `Authorization: Bearer <token>` on the RESPONSE, which is how
  /// `/auth/mobile/login-patient` hands the token to a native client.
  String? _tokenFromAuthorizationHeader(Response<dynamic> response) {
    final String? raw = response.headers.value('authorization');
    if (raw == null || raw.isEmpty) return null;
    const String prefix = 'Bearer ';
    final String token = raw.startsWith(prefix)
        ? raw.substring(prefix.length)
        : raw;
    return token.isEmpty ? null : token.trim();
  }

  /// Pulls `jwt` out of the `Set-Cookie` header(s).
  ///
  /// A `Set-Cookie` value looks like
  /// `jwt=eyJ...; Path=/; Max-Age=300; HttpOnly; SameSite=Lax`, and there can
  /// be several headers. This finds the `jwt` one and takes everything up to
  /// the first `;`.
  ///
  /// `HttpOnly` is not an obstacle: it is an instruction to browsers, and Dio
  /// is not one. The flag still does its job where it matters — the Angular
  /// app, where it keeps the token away from JavaScript.
  String? _tokenFromSetCookie(Response<dynamic> response) {
    final List<String>? cookies = response.headers.map['set-cookie'];
    if (cookies == null) return null;

    for (final String cookie in cookies) {
      for (final String part in cookie.split(';')) {
        final String trimmed = part.trim();
        if (!trimmed.startsWith('jwt=')) continue;
        final String value = trimmed.substring('jwt='.length);
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw ServerException(
      message: 'Respuesta inesperada del servidor.',
      data: data?.toString(),
    );
  }
}
