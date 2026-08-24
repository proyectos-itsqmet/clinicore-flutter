import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/domain/entities/appointment.dart';
import 'package:clinicore_flutter/features/home/domain/entities/availability.dart';
import 'package:clinicore_flutter/features/home/domain/entities/patient_profile.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/appointments_repository.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/booking_repository.dart';
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
}

class FakeBookingRepository implements BookingRepository {
  Either<Failure, BookingOptions> optionsResult = Right(
    BookingOptions(doctors: testDoctors, services: testServices),
  );

  Either<Failure, BookingAvailability> availabilityResult = Right(
    BookingAvailability(slots: testSlots),
  );

  Either<Failure, Appointment> bookResult = const Right<Failure, Appointment>(
    Appointment(id: 41, ticket: 7, status: TurnStatus.pending),
  );

  /// The schedule id the screen tried to book. This is the assertion that
  /// matters most in the booking flow: tapping "09:00" must POST the id of the
  /// 09:00 slot and not the index of the chip.
  int? lastBookedScheduleId;

  String? lastDoctorId;
  int? lastServiceId;

  @override
  Future<Either<Failure, BookingOptions>> getOptions() async => optionsResult;

  @override
  Future<Either<Failure, BookingAvailability>> getAvailability({
    required String doctorId,
    required int serviceId,
    DateTime? from,
    DateTime? to,
  }) async {
    lastDoctorId = doctorId;
    lastServiceId = serviceId;
    return availabilityResult;
  }

  @override
  Future<Either<Failure, Appointment>> book(int scheduleId) async {
    lastBookedScheduleId = scheduleId;
    return bookResult;
  }
}

// ==========================================================
// FIXTURES
// ==========================================================

const List<BookingDoctor> testDoctors = <BookingDoctor>[
  BookingDoctor(uuid: 'd-1', fullName: 'Ana Torres', speciality: 'Pediatria'),
  BookingDoctor(uuid: 'd-2', fullName: 'Luis Mora', speciality: 'Cardiologia'),
];

const List<BookingService> testServices = <BookingService>[
  BookingService(id: 1, name: 'Consulta', price: 30),
  // The second one carries a discount, so the price rows' two branches are
  // both reachable from a test.
  BookingService(id: 2, name: 'Control', price: 30, discount: 18),
];

/// A fixed day so the tests do not depend on when they run.
final DateTime testDay = DateTime(2026, 11, 12);

/// 08:40 is TAKEN, on purpose: the board strikes taken slots through rather
/// than hiding them, and "a taken slot cannot be picked" is a real test.
final List<BookingSlot> testSlots = <BookingSlot>[
  BookingSlot(scheduleId: 101, date: testDay, time: '08:40', isFree: false),
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
