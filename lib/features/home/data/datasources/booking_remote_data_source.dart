import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/availability_model.dart';
import '../models/turn_model.dart';

/// Talks to the three endpoints "Agendar" is built from, plus the one that
/// books.
///
/// ## Page sizes are large on purpose
///
/// Every one of these is paginated and every default page is 10. A clinic with
/// twelve doctors would silently show ten; a week of 20-minute slots is around
/// 150 rows, so a day grid built from page 0 would be missing every afternoon
/// with no error anywhere. The sizes below are ceilings chosen to be past any
/// realistic count for one clinic, and each one is checked — see
/// [_warnIfTruncated].
abstract interface class BookingRemoteDataSource {
  Future<List<BookingDoctorModel>> fetchDoctors();

  Future<List<BookingServiceModel>> fetchServices();

  /// Free and taken slots for one doctor + service, over a date range.
  ///
  /// Taken ones come back too: the board strikes them through rather than
  /// hiding them, so the filter is on doctor/service/date and NOT on status.
  Future<List<BookingSlotModel>> fetchSlots({
    required String doctorId,
    required int serviceId,
    required DateTime from,
    required DateTime to,
  });

  /// Books [scheduleId] for the patient in the token.
  Future<TurnModel> bookTurn(int scheduleId);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  const BookingRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static const int _doctorPageSize = 200;
  static const int _servicePageSize = 200;

  /// A month of 20-minute slots for one doctor is roughly 500. 1000 is the
  /// ceiling; the range this app asks for is 60 days, and [_warnIfTruncated]
  /// says so out loud if that ever stops being enough.
  static const int _slotPageSize = 1000;

  @override
  Future<List<BookingDoctorModel>> fetchDoctors() async {
    final PageModel<BookingDoctorModel> page = await _getPage(
      ApiEndpoints.doctors,
      <String, dynamic>{'page': 0, 'size': _doctorPageSize},
      BookingDoctorModel.fromJson,
    );
    _warnIfTruncated('doctors', page, _doctorPageSize);
    return page.content;
  }

  @override
  Future<List<BookingServiceModel>> fetchServices() async {
    final PageModel<BookingServiceModel> page = await _getPage(
      ApiEndpoints.services,
      <String, dynamic>{'page': 0, 'size': _servicePageSize},
      BookingServiceModel.fromJson,
    );
    _warnIfTruncated('services', page, _servicePageSize);
    return page.content;
  }

  @override
  Future<List<BookingSlotModel>> fetchSlots({
    required String doctorId,
    required int serviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final PageModel<BookingSlotModel> page = await _getPage(
      ApiEndpoints.schedules,
      <String, dynamic>{
        'page': 0,
        'size': _slotPageSize,
        'doctorId': doctorId,
        'serviceId': serviceId,
        'from': _isoDate(from),
        'to': _isoDate(to),
        // No `status`: taken slots are shown struck through, so they have to
        // come back. See the interface doc.
      },
      BookingSlotModel.fromJson,
    );
    _warnIfTruncated('schedules', page, _slotPageSize);
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
  /// which for an availability grid means a patient concluding there is no
  /// appointment when there is. It logs rather than throws: a truncated list is
  /// still usable, and refusing to render it would be worse than rendering it
  /// incompletely. It is a signal to paginate properly, not an error the
  /// patient caused.
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
