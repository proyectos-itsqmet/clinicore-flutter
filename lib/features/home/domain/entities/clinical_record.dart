import 'package:equatable/equatable.dart';

/// One medication line inside a [PrescriptionRecord].
///
/// Mirrors the server's `PrescriptionItemDTO` field for field. A prescription
/// is never a single paragraph: each medication carries its OWN dosage,
/// frequency and duration, and collapsing them into one block of text would
/// lose exactly the detail a patient needs to take the drug correctly.
class PrescriptionItemEntry extends Equatable {
  const PrescriptionItemEntry({
    required this.medication,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  final String medication;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;

  @override
  List<Object?> get props => <Object?>[
    medication,
    dosage,
    frequency,
    duration,
    instructions,
  ];
}

/// One prescription issued during an encounter.
///
/// Immutable once issued on the server (`PrescriptionController` has no
/// `PUT`/`DELETE`), so this app never offers to edit or delete one — it only
/// ever reads it.
class PrescriptionRecord extends Equatable {
  const PrescriptionRecord({
    required this.id,
    required this.encounterId,
    required this.items,
    this.notes,
    this.createdAt,
  });

  final int id;

  /// Links back to the [EncounterRecord] it was issued during — the key
  /// `HistoryBloc` joins on.
  final int encounterId;

  final List<PrescriptionItemEntry> items;
  final String? notes;
  final DateTime? createdAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    encounterId,
    items,
    notes,
    createdAt,
  ];
}

/// One documented consultation.
///
/// [turnId] is what `HistoryBloc` joins against `Appointment.id` with: an
/// Encounter is the clinical record OF a turn, one-to-one, and the server
/// enforces that at the database level (`turn_id` unique, not nullable) — see
/// the `Encounter` entity in `Backend_QMS`. A turn attended before this
/// feature existed, or simply not yet documented, has no matching
/// [EncounterRecord] — that is expected, not an error.
class EncounterRecord extends Equatable {
  const EncounterRecord({
    required this.id,
    required this.turnId,
    required this.reasonForVisit,
    required this.diagnosis,
    this.clinicalNotes,
    this.visitDate,
    this.doctorFullName,
    this.createdAt,
  });

  final int id;
  final int turnId;
  final String reasonForVisit;
  final String diagnosis;
  final String? clinicalNotes;
  final DateTime? visitDate;
  final String? doctorFullName;
  final DateTime? createdAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    turnId,
    reasonForVisit,
    diagnosis,
    clinicalNotes,
    visitDate,
    doctorFullName,
    createdAt,
  ];
}
