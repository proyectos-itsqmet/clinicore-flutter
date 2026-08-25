import '../../domain/entities/clinical_record.dart';
import 'json_reader.dart';

/// The backend's `EncounterDTO`.
///
/// `turnId` is what `HistoryBloc` joins against `Appointment.id` with — see
/// `EncounterController.getMyHistory`: `/api/encounters/me` returns every
/// documented visit for the caller, flat, not nested under its turn.
class EncounterModel {
  const EncounterModel({
    required this.id,
    required this.turnId,
    required this.reasonForVisit,
    required this.diagnosis,
    this.clinicalNotes,
    this.visitDate,
    this.doctorFullName,
    this.createdAt,
  });

  factory EncounterModel.fromJson(Map<String, dynamic> json) {
    return EncounterModel(
      id: readInt(json['id']),
      turnId: readInt(json['turnId']),
      reasonForVisit: readString(json['reasonForVisit']),
      diagnosis: readString(json['diagnosis']),
      clinicalNotes: readStringOrNull(json['clinicalNotes']),
      visitDate: readDate(json['visitDate']),
      doctorFullName: readStringOrNull(json['doctorFullName']),
      createdAt: readDate(json['createdAt']),
    );
  }

  final int id;
  final int turnId;
  final String reasonForVisit;
  final String diagnosis;
  final String? clinicalNotes;
  final DateTime? visitDate;
  final String? doctorFullName;
  final DateTime? createdAt;

  EncounterRecord toEntity() => EncounterRecord(
    id: id,
    turnId: turnId,
    reasonForVisit: reasonForVisit,
    diagnosis: diagnosis,
    clinicalNotes: clinicalNotes,
    visitDate: visitDate,
    doctorFullName: doctorFullName,
    createdAt: createdAt,
  );
}
