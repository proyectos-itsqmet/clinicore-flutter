import 'package:equatable/equatable.dart';

import 'appointment.dart';
import 'clinical_record.dart';

/// One row of "Historial": an attended visit, plus whatever clinical detail
/// the server has documented for it.
///
/// [appointment] always exists — it comes from [AppointmentScope.attended],
/// which is every turn the clinic already marked treated, encounter or not.
/// That is deliberate: creating an [EncounterRecord] is a SEPARATE action a
/// doctor takes after treating a turn (`POST /api/encounters`), so a turn
/// attended before this feature existed — or simply not yet documented — has
/// no [encounter]. It must still show up as a real visit, just without the
/// clinical summary, rather than disappearing from the list.
class HistoryEntry extends Equatable {
  const HistoryEntry({
    required this.appointment,
    this.encounter,
    this.prescriptions = const <PrescriptionRecord>[],
  });

  final Appointment appointment;

  /// Null when this visit has not been documented yet.
  final EncounterRecord? encounter;

  /// Every prescription issued during [encounter]. Always empty when
  /// [encounter] is null — there is no prescription without an encounter to
  /// hang it on server-side (`PrescriptionDTO.encounterId` is required).
  final List<PrescriptionRecord> prescriptions;

  bool get hasClinicalDetail => encounter != null;

  @override
  List<Object?> get props => <Object?>[appointment, encounter, prescriptions];
}
