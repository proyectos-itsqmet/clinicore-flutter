import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/encounter_model.dart';
import '../models/prescription_model.dart';
import '../models/turn_model.dart';

/// Talks to `/api/encounters/me` and `/api/prescriptions/me`.
///
/// Same "/me" idiom as [ApiEndpoints.turnsMe]: the server resolves the
/// patient from the token, so neither call takes a parameter — see
/// `EncounterController.getMyHistory` and
/// `PrescriptionController.getMyPrescriptions`.
///
/// **Reading either is AUDITED server-side.** Every call writes a
/// `ClinicalAccessLog` row (`ClinicalAccessLogService.record`, invoked from
/// both `EncounterService.getMyHistory` and
/// `PrescriptionService.getMyPrescriptions`). That is why nothing above this
/// class calls it on a timer or from `build()` — see `HistoryBloc`'s class
/// doc: it fetches once on entry and once per explicit pull-to-refresh,
/// never on every rebuild.
abstract interface class ClinicalRemoteDataSource {
  /// [size] defaults well above the appointments list's own default (see
  /// `GetMyAppointmentsParams.size`) for the same reason: "Historial" wants
  /// every attended visit's clinical detail in one screen, and a patient
  /// with a long history missing entries because they fell on page 2 would
  /// look like a data bug, not a page boundary. Not truly paginated past
  /// that — same honestly-stated limit `AppointmentsRemoteDataSourceImpl`
  /// documents for merging multiple turn statuses.
  Future<PageModel<EncounterModel>> fetchMyEncounters({
    int page = 0,
    int size = 50,
  });

  Future<PageModel<PrescriptionModel>> fetchMyPrescriptions({
    int page = 0,
    int size = 50,
  });
}

class ClinicalRemoteDataSourceImpl implements ClinicalRemoteDataSource {
  const ClinicalRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<PageModel<EncounterModel>> fetchMyEncounters({
    int page = 0,
    int size = 50,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.encountersMe,
        queryParameters: <String, dynamic>{'page': page, 'size': size},
      );
      return PageModel<EncounterModel>.fromJson(
        _asMap(response.data),
        EncounterModel.fromJson,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<PageModel<PrescriptionModel>> fetchMyPrescriptions({
    int page = 0,
    int size = 50,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.prescriptionsMe,
        queryParameters: <String, dynamic>{'page': page, 'size': size},
      );
      return PageModel<PrescriptionModel>.fromJson(
        _asMap(response.data),
        PrescriptionModel.fromJson,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerException(
      message: 'El servidor devolvio una respuesta inesperada.',
      data: data?.toString(),
    );
  }
}
