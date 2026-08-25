import 'package:clinicore_flutter/core/error/exceptions.dart';
import 'package:clinicore_flutter/features/home/data/datasources/booking_remote_data_source.dart';
import 'package:clinicore_flutter/features/home/data/datasources/clinical_remote_data_source.dart';
import 'package:clinicore_flutter/features/home/data/datasources/coverage_remote_data_source.dart';
import 'package:clinicore_flutter/features/home/data/models/availability_model.dart';
import 'package:clinicore_flutter/features/home/data/models/coverage_model.dart';
import 'package:clinicore_flutter/features/home/data/models/encounter_model.dart';
import 'package:clinicore_flutter/features/home/data/models/establishment_model.dart';
import 'package:clinicore_flutter/features/home/data/models/prescription_model.dart';
import 'package:clinicore_flutter/features/home/data/models/turn_model.dart';

/// A hand-written double for the home feature's DATA-layer booking
/// interface.
///
/// Same reasoning as `FakeAuthRemoteDataSource`: no Dio sits at this
/// boundary, so nothing here needs a mocking package. This exists to test
/// [BookingRepositoryImpl] itself — the one place two regressions could
/// silently come back:
///
/// * A service's doctors being pushed in COMPLETION order instead of the
///   services' own order (`clinicore-angular`'s `loadServicesForEstablishment`
///   bug).
/// * A doctor filter applied to the RESULT instead of sent WITH the request
///   (`clinicore-angular`'s `loadAvailableSchedules` bug).
///
/// [doctorDelayByServiceId] is what makes the first one reproducible: a plain
/// map of canned results has no notion of WHEN each future resolves, and
/// "resolves out of order" is exactly the condition the regression needs.
class FakeBookingRemoteDataSource implements BookingRemoteDataSource {
  List<EstablishmentModel> establishments = <EstablishmentModel>[];
  AppException? establishmentsError;

  /// Keyed by establishment id.
  Map<int, List<BookingServiceModel>> servicesByEstablishment =
      <int, List<BookingServiceModel>>{};
  AppException? servicesError;
  int? lastServicesEstablishmentId;

  /// Keyed by service id.
  Map<int, List<BookingDoctorModel>> doctorsByService =
      <int, List<BookingDoctorModel>>{};

  /// Keyed by service id. Lets a test make an EARLIER service resolve
  /// LATER than a later one, without touching the repository at all.
  Map<int, Duration> doctorDelayByServiceId = <int, Duration>{};
  AppException? doctorsError;

  /// Every service id a doctor fetch was requested for, in request order —
  /// not completion order.
  final List<int> doctorsRequestedForServiceIds = <int>[];

  List<BookingSlotModel> schedules = <BookingSlotModel>[];
  AppException? schedulesError;
  int? lastScheduleEstablishmentId;
  int? lastScheduleServiceId;
  String? lastScheduleDoctorId;
  DateTime? lastScheduleDate;

  TurnModel bookResult = const TurnModel(
    id: 41,
    order: 7,
    status: 'TURN_PENDING',
  );
  AppException? bookError;
  int? lastBookedScheduleId;

  @override
  Future<List<EstablishmentModel>> fetchEstablishments() async {
    final AppException? error = establishmentsError;
    if (error != null) throw error;
    return establishments;
  }

  @override
  Future<List<BookingServiceModel>> fetchServicesForEstablishment(
    int establishmentId,
  ) async {
    lastServicesEstablishmentId = establishmentId;
    final AppException? error = servicesError;
    if (error != null) throw error;
    return servicesByEstablishment[establishmentId] ??
        const <BookingServiceModel>[];
  }

  @override
  Future<List<BookingDoctorModel>> fetchDoctorsForService(
    int serviceId,
  ) async {
    doctorsRequestedForServiceIds.add(serviceId);

    final Duration delay = doctorDelayByServiceId[serviceId] ?? Duration.zero;
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final AppException? error = doctorsError;
    if (error != null) throw error;
    return doctorsByService[serviceId] ?? const <BookingDoctorModel>[];
  }

  @override
  Future<List<BookingSlotModel>> fetchFreeSchedules({
    required int establishmentId,
    required int serviceId,
    String? doctorId,
    DateTime? date,
  }) async {
    lastScheduleEstablishmentId = establishmentId;
    lastScheduleServiceId = serviceId;
    lastScheduleDoctorId = doctorId;
    lastScheduleDate = date;

    final AppException? error = schedulesError;
    if (error != null) throw error;
    return schedules;
  }

  @override
  Future<TurnModel> bookTurn(int scheduleId) async {
    lastBookedScheduleId = scheduleId;
    final AppException? error = bookError;
    if (error != null) throw error;
    return bookResult;
  }
}

/// A hand-written double for `/api/encounters/me` and
/// `/api/prescriptions/me`.
///
/// Exists to test `ClinicalRepositoryImpl` itself, one layer below the
/// `FakeClinicalRepository` the bloc tests use — same split
/// `booking_repository_impl_test.dart` uses for booking.
class FakeClinicalRemoteDataSource implements ClinicalRemoteDataSource {
  PageModel<EncounterModel> encountersPage = const PageModel<EncounterModel>(
    content: <EncounterModel>[],
    number: 0,
    last: true,
    totalElements: 0,
  );
  AppException? encountersError;

  PageModel<PrescriptionModel> prescriptionsPage =
      const PageModel<PrescriptionModel>(
        content: <PrescriptionModel>[],
        number: 0,
        last: true,
        totalElements: 0,
      );
  AppException? prescriptionsError;

  @override
  Future<PageModel<EncounterModel>> fetchMyEncounters({
    int page = 0,
    int size = 50,
  }) async {
    final AppException? error = encountersError;
    if (error != null) throw error;
    return encountersPage;
  }

  @override
  Future<PageModel<PrescriptionModel>> fetchMyPrescriptions({
    int page = 0,
    int size = 50,
  }) async {
    final AppException? error = prescriptionsError;
    if (error != null) throw error;
    return prescriptionsPage;
  }
}

/// A hand-written double for `/api/patient-coverages/me`.
class FakeCoverageRemoteDataSource implements CoverageRemoteDataSource {
  List<CoverageModel> coverages = <CoverageModel>[];
  AppException? coveragesError;

  @override
  Future<List<CoverageModel>> fetchMyCoverages() async {
    final AppException? error = coveragesError;
    if (error != null) throw error;
    return coverages;
  }
}
