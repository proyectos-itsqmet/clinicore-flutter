import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/patient_profile.dart';
import '../models/patient_model.dart';

/// Talks to `/api/patients` for the signed-in patient.
///
/// Both calls are token-only: the server reads the patient's UUID out of the
/// JWT, so neither takes an id. `AuthInterceptor` attaches the token to
/// everything that is not in its anonymous list, and these are not — nothing
/// extra to do here.
///
/// **They only work with the 24h LOGIN token.** The registration flash token
/// carries the email as its subject, not the UUID, so calling these mid-signup
/// yields a 401. In practice that cannot happen — the profile screens live
/// behind the router's auth guard — but it is the reason
/// `PatientController.getMyProfile` catches `IllegalArgumentException`
/// separately from a missing patient.
abstract interface class PatientRemoteDataSource {
  Future<PatientModel> fetchMyProfile();

  /// Returns the profile as the server left it, not as the caller sent it.
  /// The two differ whenever the server ignored a field, which for identity
  /// data is always.
  Future<PatientModel> updateMyContact(PatientContactUpdate update);

  /// Sets a new password for the signed-in patient.
  ///
  /// Returns nothing: the 200 body is a confirmation message, and there is no
  /// state for the app to update — the JWT in hand is stateless and keeps
  /// working, because `PatientService.updatePassword` only re-encodes the
  /// stored hash.
  ///
  /// Both values go to the server because the server is what compares them.
  /// See [ApiEndpoints.patientChangePassword] for what it does NOT check.
  Future<void> changeMyPassword({
    required String password,
    required String repeatedPassword,
  });
}

class PatientRemoteDataSourceImpl implements PatientRemoteDataSource {
  const PatientRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<PatientModel> fetchMyProfile() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.patientMe,
      );
      return PatientModel.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<PatientModel> updateMyContact(PatientContactUpdate update) async {
    try {
      final Response<dynamic> response = await _dio.put<dynamic>(
        ApiEndpoints.patientMeUpdate,
        data: PatientContactUpdateModel(update).toJson(),
      );
      return PatientModel.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> changeMyPassword({
    required String password,
    required String repeatedPassword,
  }) async {
    try {
      await _dio.put<dynamic>(
        ApiEndpoints.patientChangePassword,
        data: <String, dynamic>{
          'password': password,
          'repeatedPassword': repeatedPassword,
        },
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// A 200 whose body is not an object is a contract break, not a user error,
  /// so it fails loudly instead of decoding into an empty profile that would
  /// render as a screen full of blanks.
  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerException(
      message: 'El servidor devolvio una respuesta inesperada.',
      data: data?.toString(),
    );
  }
}
