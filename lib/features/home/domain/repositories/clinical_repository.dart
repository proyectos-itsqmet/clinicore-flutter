import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/clinical_record.dart';

/// What the app can ask about the signed-in patient's documented visits.
///
/// Two calls, never merged into one here: `HistoryBloc` is the one place
/// that joins an [EncounterRecord] to the `Appointment` it documents and to
/// the [PrescriptionRecord]s issued during it — see `HistoryEntry`. Neither
/// call takes a parameter; both resolve the patient from the token, same as
/// `AppointmentsRepository.getMyAppointments`.
abstract interface class ClinicalRepository {
  Future<Either<Failure, List<EncounterRecord>>> getMyEncounters();

  Future<Either<Failure, List<PrescriptionRecord>>> getMyPrescriptions();
}
