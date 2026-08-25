import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/coverage_model.dart';
import '../models/json_reader.dart';

/// Talks to `/api/patient-coverages/me`.
///
/// Same "/me" idiom as this feature's other data sources. Unlike encounters
/// and prescriptions this is NOT a `Page` on the wire —
/// `PatientCoverageController.getMyCoverages` returns a plain
/// `List<PatientCoverageDTO>` — so there is no `PageModel` envelope to decode
/// through here.
///
/// **Not audited.** `PatientCoverageService` never calls
/// `ClinicalAccessLogService` — coverage is billing data, not a clinical
/// record. This still fetches deliberately (on entry, on explicit retry) for
/// the plainer reason every read-only bloc in this app does: nothing gains
/// from asking again before the caller asks again.
abstract interface class CoverageRemoteDataSource {
  Future<List<CoverageModel>> fetchMyCoverages();
}

class CoverageRemoteDataSourceImpl implements CoverageRemoteDataSource {
  const CoverageRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<CoverageModel>> fetchMyCoverages() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.patientCoveragesMe,
      );
      return readMapList(response.data).map(CoverageModel.fromJson).toList();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
