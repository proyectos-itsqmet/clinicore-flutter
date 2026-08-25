import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/appointment.dart';
import '../models/turn_model.dart';

/// Talks to `/api/turns/me`.
///
/// **Never `/api/turns`.** That endpoint returns every turn in the system —
/// other patients' names, emails and cedulas included — and filtering it
/// client-side would mean downloading them first. `/me` filters by the patient
/// in the token, server-side, which is the only correct version of this call.
abstract interface class AppointmentsRemoteDataSource {
  /// [statuses] is a LIST because the tabs are not one status each: "Proximas"
  /// is pending + waiting + in-treatment, "Pasadas" is treated + cancelled.
  /// The server takes a single `status` per request, so more than one status
  /// means more than one request — see the impl.
  Future<PageModel<TurnModel>> fetchMyTurns({
    List<TurnStatus> statuses = const <TurnStatus>[],
    int page = 0,
    int size = 20,
  });

  /// Cancels one of the CALLER's own turns.
  ///
  /// Ownership is checked server-side against the token, never against
  /// anything sent here — see `ApiEndpoints.turnCancelled`. Returns the
  /// updated turn, `TURN_CANCELLED`, the same shape booking returns.
  Future<TurnModel> cancelTurn(int turnId);
}

class AppointmentsRemoteDataSourceImpl implements AppointmentsRemoteDataSource {
  const AppointmentsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<PageModel<TurnModel>> fetchMyTurns({
    List<TurnStatus> statuses = const <TurnStatus>[],
    int page = 0,
    int size = 20,
  }) async {
    // No filter: one request, and the caller sorts out what it got.
    if (statuses.isEmpty) {
      return _fetchPage(status: null, page: page, size: size);
    }

    // One status: still one request, still really paginated.
    if (statuses.length == 1) {
      return _fetchPage(status: statuses.single, page: page, size: size);
    }

    // MORE THAN ONE STATUS is where this gets honest about a server
    // limitation. `TurnRepository.findTurnsForPatient` takes ONE `status`, so
    // "Proximas" (three statuses) cannot be a single query. The options were:
    //
    //   a) ask for everything unfiltered and filter on the device — downloads
    //      the patient's whole history to show two cards;
    //   b) add a `statuses` list parameter to the backend — the right fix, and
    //      not this app's to make unilaterally;
    //   c) one request per status, merged here.
    //
    // (c), with the cost stated plainly: the RESULT IS NOT PAGINATED. Each
    // status is asked for its first `size` rows and the union is sorted by
    // date; `isLast` is true only when every branch said so, so a caller that
    // paginates will not silently lose rows — it will just see that there is
    // no more to ask for through this path. For a patient's own appointments
    // that ceiling is far away; if it ever is not, do (b).
    final List<PageModel<TurnModel>> pages = await Future.wait(
      statuses.map(
        (TurnStatus status) => _fetchPage(status: status, page: 0, size: size),
      ),
    );

    final List<TurnModel> merged = <TurnModel>[
      for (final PageModel<TurnModel> p in pages) ...p.content,
    ];

    return PageModel<TurnModel>(
      content: merged,
      number: 0,
      last: pages.every((PageModel<TurnModel> p) => p.last),
      totalElements: pages.fold<int>(
        0,
        (int sum, PageModel<TurnModel> p) => sum + p.totalElements,
      ),
    );
  }

  @override
  Future<TurnModel> cancelTurn(int turnId) async {
    try {
      final Response<dynamic> response = await _dio.put<dynamic>(
        ApiEndpoints.turnCancelled(turnId),
      );
      return TurnModel.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<PageModel<TurnModel>> _fetchPage({
    required TurnStatus? status,
    required int page,
    required int size,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.turnsMe,
        queryParameters: <String, dynamic>{
          'page': page,
          'size': size,
          // Omitted rather than sent empty: Spring maps `?status=` to a blank
          // string, which does not parse as the enum and answers 400.
          if (status?.apiValue != null) 'status': status!.apiValue,
        },
      );

      return PageModel<TurnModel>.fromJson(
        _asMap(response.data),
        TurnModel.fromJson,
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
