import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/availability_model.dart';
import '../models/establishment_model.dart';
import '../models/turn_model.dart';

/// Talks to the four endpoints the "Agendar" wizard's steps are built from,
/// plus the one that books.
///
/// ## Page sizes are large on purpose
///
/// Every one of these is paginated and every default page is 10. A clinic
/// with more than ten sedes, or a service with more than ten doctors, would
/// silently show a truncated list with no error anywhere. The sizes below
/// are ceilings chosen to be past any realistic count for one clinic, and
/// each one is checked — see [_warnIfTruncated].
abstract interface class BookingRemoteDataSource {
  /// Step 1. Fetches the whole first page rather than taking a search term:
  /// the wizard filters the loaded list locally — see
  /// `BookingState.visibleEstablishments`.
  Future<List<EstablishmentModel>> fetchEstablishments();

  /// Step 2's services, scoped to the sede chosen in step 1.
  Future<List<BookingServiceModel>> fetchServicesForEstablishment(
    int establishmentId,
  );

  /// Step 2's doctors for ONE service, regardless of establishment — the
  /// backend has no "doctors at this service AND this sede" endpoint.
  Future<List<BookingDoctorModel>> fetchDoctorsForService(int serviceId);

  /// Step 3's FREE slots, filtered on the SERVER by every parameter given.
  ///
  /// [doctorId] and [date] are optional. When [doctorId] is null, no
  /// `doctorId` query parameter is sent at all — never a request that
  /// fetches everyone's slots and drops the wrong ones afterwards. That is
  /// the whole difference from `clinicore-angular`'s
  /// `getSchedules`/`loadAvailableSchedules`, which calls the endpoint
  /// nested under `/api/services/{id}/schedules` (no `doctorId` parameter
  /// exists there) and filters the doctor out of the response instead.
  Future<List<BookingSlotModel>> fetchFreeSchedules({
    required int establishmentId,
    required int serviceId,
    String? doctorId,
    DateTime? date,
  });

  /// Books [scheduleId] for the patient in the token.
  Future<TurnModel> bookTurn(int scheduleId);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  const BookingRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static const int _establishmentPageSize = 200;
  static const int _servicePageSize = 200;
  static const int _doctorPageSize = 50;

  /// A month of 20-minute FREE slots for one doctor is roughly 500. 1000 is
  /// the ceiling — a list built from page 0 silently missing the rest is
  /// worse than one extra digit here.
  static const int _schedulePageSize = 1000;

  @override
  Future<List<EstablishmentModel>> fetchEstablishments() async {
    final PageModel<EstablishmentModel> page = await _getPage(
      ApiEndpoints.stablishments,
      <String, dynamic>{'page': 0, 'size': _establishmentPageSize},
      EstablishmentModel.fromJson,
    );
    _warnIfTruncated('stablishments', page, _establishmentPageSize);
    return page.content;
  }

  @override
  Future<List<BookingServiceModel>> fetchServicesForEstablishment(
    int establishmentId,
  ) async {
    final PageModel<BookingServiceModel> page = await _getPage(
      ApiEndpoints.stablishmentServices(establishmentId),
      <String, dynamic>{'page': 0, 'size': _servicePageSize},
      BookingServiceModel.fromJson,
    );
    _warnIfTruncated('stablishment services', page, _servicePageSize);
    return page.content;
  }

  @override
  Future<List<BookingDoctorModel>> fetchDoctorsForService(
    int serviceId,
  ) async {
    final PageModel<BookingDoctorModel> page = await _getPage(
      ApiEndpoints.serviceDoctors(serviceId),
      <String, dynamic>{'page': 0, 'size': _doctorPageSize},
      BookingDoctorModel.fromJson,
    );
    _warnIfTruncated('service doctors', page, _doctorPageSize);
    return page.content;
  }

  @override
  Future<List<BookingSlotModel>> fetchFreeSchedules({
    required int establishmentId,
    required int serviceId,
    String? doctorId,
    DateTime? date,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'page': 0,
      'size': _schedulePageSize,
      'serviceId': serviceId,
      'stablishmentId': establishmentId,
      // Only what can actually be booked — unlike the old day grid, this
      // step never shows a taken slot struck through, so nothing above this
      // line needs one either.
      'status': 'STATUS_FREE',
    };

    // Added to the QUERY, never to a `.where(...)` on the response below —
    // see this method's doc comment for the bug that distinction fixes.
    if (doctorId != null) query['doctorId'] = doctorId;
    if (date != null) query['date'] = _isoDate(date);

    final PageModel<BookingSlotModel> page = await _getPage(
      ApiEndpoints.schedules,
      query,
      BookingSlotModel.fromJson,
    );
    _warnIfTruncated('free schedules', page, _schedulePageSize);
    return page.content;
  }

  @override
  Future<TurnModel> bookTurn(int scheduleId) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.turns,
        // The whole body. `TurnService.create` resolves the patient from the
        // token and assigns the next `order` itself, so the schedule is the
        // only thing the client gets to choose — and sending a patient here
        // would be ignored anyway.
        data: <String, dynamic>{
          'schedule': <String, dynamic>{'id': scheduleId},
        },
      );
      return TurnModel.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<PageModel<T>> _getPage<T>(
    String path,
    Map<String, dynamic> query,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
      );
      return PageModel<T>.fromJson(_asMap(response.data), fromJson);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// Says so when a ceiling was actually hit.
  ///
  /// The alternative to this line is a screen that quietly shows a subset —
  /// for a list of sedes or a list of slots that means a patient concluding
  /// there is nothing when there is. It logs rather than throws: a truncated
  /// list is still usable, and refusing to render it would be worse than
  /// rendering it incompletely. It is a signal to paginate properly, not an
  /// error the patient caused.
  void _warnIfTruncated<T>(String what, PageModel<T> page, int requested) {
    if (page.last) return;
    assert(() {
      // ignore: avoid_print
      print(
        'BookingRemoteDataSource: $what returned a full page of $requested '
        'and reports more (total ${page.totalElements}). The list is '
        'TRUNCATED — this needs real pagination.',
      );
      return true;
    }());
  }

  /// `yyyy-MM-dd`. The server's `@DateTimeFormat(iso = ISO.DATE)` accepts
  /// nothing else, and sending a full ISO instant answers 400.
  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerException(
      message: 'El servidor devolvio una respuesta inesperada.',
      data: data?.toString(),
    );
  }
}
