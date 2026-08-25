import 'dart:async';

import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/domain/entities/appointment.dart';
import 'package:clinicore_flutter/features/home/domain/entities/availability.dart';
import 'package:clinicore_flutter/features/home/domain/entities/clinical_record.dart';
import 'package:clinicore_flutter/features/home/domain/entities/coverage.dart';
import 'package:clinicore_flutter/features/home/domain/entities/establishment.dart';
import 'package:clinicore_flutter/features/home/domain/entities/patient_profile.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/appointments_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/booking_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/clinical_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/coverage_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/patient_repository.dart';
import 'package:dartz/dartz.dart';

/// Hand-written doubles for the home feature's three repositories.
///
/// Same reasoning as [FakeAuthRepository]: the interfaces are small enough to
/// read top to bottom, every result is scripted through a public field, and
/// what mattered was recorded so a test can assert the screen sent the right
/// thing. No build step, no `when(...).thenReturn(...)` between a test and
/// what it means.

/// A fixed profile the profile tests read from.
///
/// The name is deliberately two words: the identity card derives its initials
/// from it, and that derivation is one of the things under test.
final PatientProfile testProfile = PatientProfile(
  uuid: 'p-1',
  email: 'ana.perez@example.com',
  firstName: 'Ana',
  lastName: 'Perez',
  cedula: '1712345678',
  birthday: DateTime(1990, 4, 12),
  gender: PatientGender.female,
  phone: '0991234567',
  address: 'Av. Siempre Viva 742',
  emergencyContactName: 'Luis Perez',
  emergencyContactPhone: '0998765432',
);

class FakePatientRepository implements PatientRepository {
  Either<Failure, PatientProfile> profileResult = Right(testProfile);
  Either<Failure, PatientProfile> updateResult = Right(testProfile);

  /// What the contact sheet actually submitted.
  PatientContactUpdate? lastUpdate;

  @override
  Future<Either<Failure, PatientProfile>> getMyProfile() async => profileResult;

  @override
  Future<Either<Failure, PatientProfile>> updateMyContact(
    PatientContactUpdate update,
  ) async {
    lastUpdate = update;
    return updateResult;
  }
}

class FakeAppointmentsRepository implements AppointmentsRepository {
  /// One result per scope, so a test can give "Proximas" two rows and
  /// "Pasadas" none without the two interfering.
  final Map<AppointmentScope, Either<Failure, AppointmentPage>> results =
      <AppointmentScope, Either<Failure, AppointmentPage>>{};

  final List<AppointmentScope> requestedScopes = <AppointmentScope>[];

  /// What cancelling answers. Defaults to success so a test only scripts this
  /// when it is actually about a cancel failure.
  Either<Failure, Appointment> cancelResult =
      const Right<Failure, Appointment>(
        Appointment(id: 1, ticket: 7, status: TurnStatus.cancelled),
      );

  /// The turn id the screen actually sent. The assertion that matters most:
  /// tapping "Cancelar turno" on one card must cancel THAT card, not another.
  int? lastCancelledId;

  int cancelCallCount = 0;

  /// The realtime feed [WatchTurnUpdates] reads from. A test pushes into it
  /// with `.add(...)` to simulate a server push, and reads `.hasListener` to
  /// confirm a bloc's subscription was torn down when it closed — see
  /// `appointments_bloc_test.dart`.
  final StreamController<Appointment> turnUpdatesController =
      StreamController<Appointment>.broadcast();

  @override
  Future<Either<Failure, AppointmentPage>> getMyAppointments({
    required AppointmentScope scope,
    int page = 0,
    int size = 20,
  }) async {
    requestedScopes.add(scope);
    return results[scope] ??
        const Right<Failure, AppointmentPage>(AppointmentPage.empty());
  }

  @override
  Future<Either<Failure, Appointment>> cancelAppointment(int turnId) async {
    lastCancelledId = turnId;
    cancelCallCount++;
    return cancelResult;
  }

  @override
  Stream<Appointment> watchTurnUpdates() => turnUpdatesController.stream;
}

class FakeBookingRepository implements BookingRepository {
  Either<Failure, List<Establishment>> establishmentsResult = const Right(
    testEstablishments,
  );

  Either<Failure, List<ServiceWithDoctors>> servicesResult = const Right(
    testServiceOffers,
  );

  Either<Failure, List<BookingSlot>> schedulesResult = Right(testSlots);

  Either<Failure, Appointment> bookResult = const Right<Failure, Appointment>(
    Appointment(id: 41, ticket: 7, status: TurnStatus.pending),
  );

  int getEstablishmentsCallCount = 0;

  /// What step 2 actually asked for. The assertion that matters: it must
  /// scope by the SAME establishment step 1 picked, not by whatever the
  /// screen fetched last.
  int? lastServicesEstablishmentId;

  /// What step 3 actually asked for. `lastSchedulesDoctorId` is the
  /// assertion that matters most in the whole wizard: it must reach THIS
  /// call, never be applied to [schedulesResult] afterwards — see
  /// `booking_bloc_test.dart`.
  int? lastSchedulesEstablishmentId;
  int? lastSchedulesServiceId;
  String? lastSchedulesDoctorId;
  DateTime? lastSchedulesDate;

  /// The schedule id the screen tried to book. This is the assertion that
  /// matters most in the booking flow: tapping a slot must POST the id of
  /// THAT slot and not the index of the chip.
  int? lastBookedScheduleId;

  @override
  Future<Either<Failure, List<Establishment>>> getEstablishments() async {
    getEstablishmentsCallCount++;
    return establishmentsResult;
  }

  @override
  Future<Either<Failure, List<ServiceWithDoctors>>> getServicesWithDoctors(
    int establishmentId,
  ) async {
    lastServicesEstablishmentId = establishmentId;
    return servicesResult;
  }

  @override
  Future<Either<Failure, List<BookingSlot>>> getFreeSchedules({
    required int establishmentId,
    required int serviceId,
    String? doctorId,
    DateTime? date,
  }) async {
    lastSchedulesEstablishmentId = establishmentId;
    lastSchedulesServiceId = serviceId;
    lastSchedulesDoctorId = doctorId;
    lastSchedulesDate = date;
    return schedulesResult;
  }

  @override
  Future<Either<Failure, Appointment>> book(int scheduleId) async {
    lastBookedScheduleId = scheduleId;
    return bookResult;
  }
}

class FakeClinicalRepository implements ClinicalRepository {
  Either<Failure, List<EncounterRecord>> encountersResult =
      const Right<Failure, List<EncounterRecord>>(<EncounterRecord>[]);

  Either<Failure, List<PrescriptionRecord>> prescriptionsResult =
      const Right<Failure, List<PrescriptionRecord>>(<PrescriptionRecord>[]);

  int getMyEncountersCallCount = 0;
  int getMyPrescriptionsCallCount = 0;

  @override
  Future<Either<Failure, List<EncounterRecord>>> getMyEncounters() async {
    getMyEncountersCallCount++;
    return encountersResult;
  }

  @override
  Future<Either<Failure, List<PrescriptionRecord>>>
  getMyPrescriptions() async {
    getMyPrescriptionsCallCount++;
    return prescriptionsResult;
  }
}

class FakeCoverageRepository implements CoverageRepository {
  Either<Failure, List<CoverageRecord>> coveragesResult =
      const Right<Failure, List<CoverageRecord>>(<CoverageRecord>[]);

  int getMyCoveragesCallCount = 0;

  @override
  Future<Either<Failure, List<CoverageRecord>>> getMyCoverages() async {
    getMyCoveragesCallCount++;
    return coveragesResult;
  }
}

// ==========================================================
// FIXTURES
// ==========================================================

/// Step 1's fixture: two sedes, so "pick a different one" is a real test.
const List<Establishment> testEstablishments = <Establishment>[
  Establishment(id: 1, name: 'Sede Norte', address: 'Av. Siempre Viva 742'),
  Establishment(id: 2, name: 'Sede Sur', address: 'Av. de los Manzanos 123'),
];

const List<BookingDoctor> testDoctors = <BookingDoctor>[
  BookingDoctor(uuid: 'd-1', fullName: 'Ana Torres', speciality: 'Pediatria'),
  BookingDoctor(uuid: 'd-2', fullName: 'Luis Mora', speciality: 'Cardiologia'),
];

const BookingService testConsultationService = BookingService(
  id: 1,
  name: 'Consulta',
  price: 30,
);

// Carries a discount, so the price rows' two branches are both reachable
// from a test.
const BookingService testControlService = BookingService(
  id: 2,
  name: 'Control',
  price: 30,
  discount: 18,
);

const List<BookingService> testServices = <BookingService>[
  testConsultationService,
  testControlService,
];

/// Step 2's fixture: `testConsultationService` names both fixture doctors;
/// `testControlService` names none, which is the "cualquier doctor
/// disponible" branch, not an error.
const List<ServiceWithDoctors> testServiceOffers = <ServiceWithDoctors>[
  ServiceWithDoctors(service: testConsultationService, doctors: testDoctors),
  ServiceWithDoctors(service: testControlService, doctors: <BookingDoctor>[]),
];

/// A fixed day so the tests do not depend on when they run.
final DateTime testDay = DateTime(2026, 11, 12);

/// Step 3's fixture. Both FREE — this step only ever lists what can
/// actually be booked, unlike the old day grid, which also rendered taken
/// slots struck through.
final List<BookingSlot> testSlots = <BookingSlot>[
  BookingSlot(scheduleId: 102, date: testDay, time: '09:00', isFree: true),
  BookingSlot(scheduleId: 103, date: testDay, time: '10:00', isFree: true),
];

/// Two upcoming appointments, one with everything filled in and one missing
/// its schedule — which is a row the server really returns.
final List<Appointment> testUpcoming = <Appointment>[
  Appointment(
    id: 1,
    ticket: 7,
    status: TurnStatus.pending,
    date: testDay,
    time: '09:00',
    doctorName: 'Ana Torres',
    speciality: 'Pediatria',
    locationName: 'Sede Norte',
  ),
  const Appointment(id: 2, ticket: 8, status: TurnStatus.waiting),
];

/// "Historial"'s fixture: two ATTENDED visits. Only the first (`id: 10`) has
/// a documented encounter — the second (`id: 11`) is what an attended turn
/// looked like before this feature existed, and `HistoryBloc` must still
/// show it.
final List<Appointment> testAttended = <Appointment>[
  Appointment(
    id: 10,
    ticket: 3,
    status: TurnStatus.treated,
    date: testDay,
    finishedAt: testDay,
    doctorName: 'Ana Torres',
    speciality: 'Pediatria',
    locationName: 'Sede Norte',
  ),
  Appointment(
    id: 11,
    ticket: 1,
    status: TurnStatus.treated,
    date: DateTime(2025, 5, 3),
    finishedAt: DateTime(2025, 5, 3),
    doctorName: 'Luis Mora',
    speciality: 'Cardiologia',
    locationName: 'Sede Sur',
  ),
];

/// Documents `testAttended[0]` (`turnId: 10`) only — `testAttended[1]` is
/// deliberately left without a match.
final List<EncounterRecord> testEncounters = <EncounterRecord>[
  EncounterRecord(
    id: 100,
    turnId: 10,
    reasonForVisit: 'Dolor de cabeza persistente',
    diagnosis: 'Migrana tensional',
    visitDate: testDay,
    doctorFullName: 'Ana Torres',
  ),
];

/// Issued during `testEncounters[0]` (`encounterId: 100`), two medications —
/// the fixture that proves a prescription renders as more than one row.
final List<PrescriptionRecord> testPrescriptions = <PrescriptionRecord>[
  PrescriptionRecord(
    id: 200,
    encounterId: 100,
    items: <PrescriptionItemEntry>[
      const PrescriptionItemEntry(
        medication: 'Ibuprofeno',
        dosage: '400mg',
        frequency: 'Cada 8 horas',
        duration: '5 dias',
        instructions: 'Tomar con alimentos',
      ),
      const PrescriptionItemEntry(
        medication: 'Paracetamol',
        dosage: '500mg',
        frequency: 'Cada 6 horas',
        duration: '3 dias',
      ),
    ],
  ),
];

/// One active policy, one lapsed — the pair every "which one is current"
/// test needs.
final CoverageRecord testActiveCoverage = CoverageRecord(
  id: 1,
  insurerName: 'Seguros Equinoccial',
  planName: 'Plan Oro',
  coveragePercentage: 80,
  policyNumber: 'POL-001',
  validFrom: DateTime(2026, 1, 1),
  active: true,
);

final CoverageRecord testExpiredCoverage = CoverageRecord(
  id: 2,
  insurerName: 'IESS',
  planName: 'Plan Basico',
  coveragePercentage: 50,
  policyNumber: 'POL-000',
  validFrom: DateTime(2020, 1, 1),
  validUntil: DateTime(2025, 12, 31),
  active: false,
);
